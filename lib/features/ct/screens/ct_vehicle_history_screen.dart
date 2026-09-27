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
  List<CtBookingModel> _history = [];
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
      final list = await CtService.instance.getVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = list;
        _loadingVehicles = false;
        if (list.isNotEmpty) _selectVehicle(list.first);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loadingVehicles = false; });
    }
  }

  Future<void> _selectVehicle(VehicleModel v) async {
    setState(() { _selected = v; _loadingHistory = true; _history = []; _error = null; });
    try {
      // Charge toutes les réservations CT et filtre par véhicule
      final all = await CtService.instance.getMyBookings();
      if (!mounted) return;
      setState(() {
        _history = all.where((b) => b.vehicle.id == v.id).toList();
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loadingHistory = false; });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed': return 'Confirmé';
      case 'pending':   return 'En attente';
      case 'cancelled': return 'Annulé';
      case 'completed': return 'Terminé';
      default:          return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed': return Colors.green;
      case 'cancelled': return AppColors.error;
      case 'completed': return AppColors.primary;
      default:          return AppColors.textSecondary;
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
                      value: _selected,
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
                                      itemBuilder: (_, i) => _BookingCard(
                                        booking: _history[i],
                                        statusLabel: _statusLabel(_history[i].status),
                                        statusColor: _statusColor(_history[i].status),
                                        formatDate: _formatDate,
                                      ),
                                    )),
                  ),
                ]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final CtBookingModel booking;
  final String statusLabel;
  final Color statusColor;
  final String Function(DateTime) formatDate;

  const _BookingCard({
    required this.booking,
    required this.statusLabel,
    required this.statusColor,
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
              color: statusColor.withAlpha(26),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          Text(formatDate(booking.slotStartsAt),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        Text(booking.center.name,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
        if (booking.center.address != null) ...[
          const SizedBox(height: 2),
          Text(booking.center.address!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Résultat VT',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text(booking.vtResult ?? 'En attente',
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
              '${booking.totalAmount.toStringAsFixed(0)} FCFA',
              style: const TextStyle(
                  color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ]),
        ]),
        if (booking.reference.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Réf : ${booking.reference}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ]),
    );
  }
}
