import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<VehicleModel> _vehicles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.instance.getVehicles();
      _vehicles = raw
          .map((v) {
            try {
              return VehicleModel.fromJson(v as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<VehicleModel>()
          .toList();
    } catch (e) {
      // Repli sur les véhicules éventuellement embarqués dans le profil
      final embedded = (context.read<AuthController>().user?.vehicles ?? [])
          .map((v) {
            try {
              return VehicleModel.fromJson(v as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<VehicleModel>()
          .toList();
      _vehicles = embedded;
      _error = embedded.isEmpty ? 'Impossible de charger les véhicules : $e' : null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ApiService.instance.deleteVehicle(id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _showAddVehicle() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddVehicleSheet(),
    );
    if (added == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes vehicules')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicle,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _vehicles.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      const Center(
                        child: Column(children: [
                          Text('🚗', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('Aucun vehicule enregistre',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 12)),
                        ),
                      ],
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vehicles.length,
                    itemBuilder: (_, i) => _VehicleTile(
                      vehicle: _vehicles[i],
                      onDelete: () => _delete(_vehicles[i].id),
                    ),
                  ),
      ),
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
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ],
        ),
        child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Center(
                  child: Text('🚗', style: TextStyle(fontSize: 24)))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${vehicle.brand} ${vehicle.model}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(vehicle.plate,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                if (vehicle.color != null)
                  Text(vehicle.color!,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
              ])),
          IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: onDelete),
        ]),
      );
}

class _AddVehicleSheet extends StatefulWidget {
  const _AddVehicleSheet();
  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_brandCtrl.text.isEmpty || _plateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Marque et immatriculation sont requis')));
      return;
    }
    setState(() => _loading = true);
    try {
      // On laisse le backend générer l'id ; on n'envoie que les champs utiles.
      await ApiService.instance.addVehicle({
        'brand': _brandCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'plate': _plateCtrl.text.trim().toUpperCase(),
        if (_colorCtrl.text.trim().isNotEmpty) 'color': _colorCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Vehicule ajoute'),
            backgroundColor: AppColors.success));
        Navigator.pop(context, true); // signale au parent de recharger
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ajouter un vehicule',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
              controller: _brandCtrl,
              decoration: const InputDecoration(
                  labelText: 'Marque *', hintText: 'Toyota')),
          const SizedBox(height: 12),
          TextField(
              controller: _modelCtrl,
              decoration: const InputDecoration(
                  labelText: 'Modele', hintText: 'Corolla')),
          const SizedBox(height: 12),
          TextField(
              controller: _plateCtrl,
              decoration: const InputDecoration(
                  labelText: 'Immatriculation *', hintText: 'AB 1234 CI'),
              textCapitalization: TextCapitalization.characters),
          const SizedBox(height: 12),
          TextField(
              controller: _colorCtrl,
              decoration: const InputDecoration(
                  labelText: 'Couleur', hintText: 'Blanc')),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Enregistrer'))),
        ]),
      );
}
