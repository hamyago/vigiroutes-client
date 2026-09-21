import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/ct_service.dart';

class CtVehicleHistoryScreen extends StatefulWidget {
  const CtVehicleHistoryScreen({super.key});

  @override
  State<CtVehicleHistoryScreen> createState() => _CtVehicleHistoryScreenState();
}

class _CtVehicleHistoryScreenState extends State<CtVehicleHistoryScreen> {
  List<VehicleModel> _vehicles = [];
  VehicleModel? _selected;
  List<VehicleInterventionModel> _history = [];
  bool _loadingVehicles = true;
  bool _loadingHistory = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() { _loadingVehicles = true; _error = null; });
    try {
      final list = await CtService.instance.getMyVehicles();
      setState(() {
        _vehicles = list;
        _loadingVehicles = false;
        if (list.isNotEmpty) _selectVehicle(list.first);
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loadingVehicles = false; });
    }
  }

  Future<void> _selectVehicle(VehicleModel v) async {
    setState(() { _selected = v; _loadingHistory = true; _history = []; _error = null; });
    try {
      final h = await CtService.instance.getVehicleHistory(v.id);
      setState(() { _history = h; _loadingHistory = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loadingHistory = false; });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _typeLabel(String type) {
    switch (type) {
      case 'ct': return 'Contrôle Technique';
      case 'repair': return 'Réparation';
      case 'maintenance': return 'Entretien';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Carnet numérique',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loadingVehicles
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _vehicles.isEmpty
              ? const Center(
                  child: Text('Aucun véhicule enregistré',
                      style: TextStyle(color: AppColors.textSecondary)))
              : Column(children: [
                  // Dropdown véhicule
                  Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: DropdownButtonFormField<VehicleModel>(
                      initialValue: _selected,
                      decoration: InputDecoration(
                        labelText: 'Véhicule',
                        labelStyle: const TextStyle(color: AppColors.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: _vehicles
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                    '${v.registrationNumber} — ${v.brand} ${v.model}',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) { if (v != null) _selectVehicle(v); },
                    ),
                  ),

                  // Historique
                  Expanded(
                    child: _loadingHistory
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.primary))
                        : _error != null
                            ? Center(
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text(_error!,
                                      style: const TextStyle(color: AppColors.error),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _selected != null
                                        ? () => _selectVehicle(_selected!)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary),
                                    child: const Text('Réessayer',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ]))
                            : _history.isEmpty
                                ? const Center(
                                    child: Text('Aucun historique trouvé',
                                        style: TextStyle(color: AppColors.textSecondary)))
                                : RefreshIndicator(
                                    color: AppColors.primary,
                                    onRefresh: () =>
                                        _selected != null ? _selectVehicle(_selected!) : Future.value(),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _history.length,
                                      itemBuilder: (_, i) =>
                                          _InterventionCard(
                                            item: _history[i],
                                            typeLabel: _typeLabel(_history[i].type),
                                            formatDate: _formatDate,
                                          ),
                                    )),
                  ),
                ]),
    );
  }
}

class _InterventionCard extends StatelessWidget {
  final VehicleInterventionModel item;
  final String typeLabel;
  final String Function(DateTime) formatDate;

  const _InterventionCard({
    required this.item,
    required this.typeLabel,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(typeLabel,
                style: const TextStyle(
                    color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          if (item.performedAt != null)
            Text(formatDate(item.performedAt!),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        Text(item.providerName,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(item.locationName,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Résultat',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text(item.result ?? 'En attente',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Montant',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            Text(
              item.amount != null
                  ? '${item.amount!.toStringAsFixed(0)} ${item.currency ?? 'FCFA'}'
                  : 'N/A',
              style: const TextStyle(
                  color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ]),
        ]),
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(item.notes!,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
        ],
        if (item.photos.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: item.photos.length,
              itemBuilder: (_, j) => Container(
                margin: const EdgeInsets.only(right: 8),
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                  image: DecorationImage(
                    image: NetworkImage(item.photos[j]),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  ),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
