import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthController>();
    final vehicles = (auth.user?.vehicles ?? [])
        .map((v) {
          try { return VehicleModel.fromJson(v as Map<String, dynamic>); }
          catch (_) { return null; }
        })
        .whereType<VehicleModel>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mes véhicules')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVehicle(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: vehicles.isEmpty
          ? const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('🚗', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Aucun véhicule enregistré',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vehicles.length,
              itemBuilder: (_, i) => _VehicleTile(
                vehicle:  vehicles[i],
                onDelete: () => _delete(context, vehicles[i].id),
              ),
            ),
    );
  }

  Future<void> _delete(BuildContext context, String id) async {
    try {
      await ApiService.instance.deleteVehicle(id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  void _showAddVehicle(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddVehicleSheet(),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback onDelete;
  const _VehicleTile({required this.vehicle, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: const Center(child: Text('🚗', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${vehicle.brand} ${vehicle.model}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(vehicle.plate,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (vehicle.color != null)
              Text(vehicle.color!,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ])),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: onDelete,
          ),
        ]),
      );
}

class _AddVehicleSheet extends StatefulWidget {
  const _AddVehicleSheet();
  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _brandCtrl  = TextEditingController();
  final _modelCtrl  = TextEditingController();
  final _plateCtrl  = TextEditingController();
  final _colorCtrl  = TextEditingController();
  bool  _loading    = false;

  @override
  void dispose() {
    _brandCtrl.dispose(); _modelCtrl.dispose();
    _plateCtrl.dispose(); _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_brandCtrl.text.isEmpty || _plateCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final vehicle = VehicleModel(
        id:     const Uuid().v4(),
        userId: '',
        brand:  _brandCtrl.text.trim(),
        model:  _modelCtrl.text.trim(),
        plate:  _plateCtrl.text.trim().toUpperCase(),
        color:  _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
      );
      await ApiService.instance.addVehicle(vehicle.toJson());
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Ajouter un véhicule',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      const SizedBox(height: 16),
      TextField(controller: _brandCtrl,
          decoration: const InputDecoration(labelText: 'Marque *', hintText: 'Toyota')),
      const SizedBox(height: 12),
      TextField(controller: _modelCtrl,
          decoration: const InputDecoration(labelText: 'Modèle', hintText: 'Corolla')),
      const SizedBox(height: 12),
      TextField(controller: _plateCtrl,
          decoration: const InputDecoration(labelText: 'Immatriculation *', hintText: 'AB 1234 CI')),
      const SizedBox(height: 12),
      TextField(controller: _colorCtrl,
          decoration: const InputDecoration(labelText: 'Couleur', hintText: 'Blanc')),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Enregistrer'),
        ),
      ),
    ]),
  );
}
