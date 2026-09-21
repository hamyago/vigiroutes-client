import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/ct_service.dart';
import 'ct_booking_detail_screen.dart';

class CtBookingsScreen extends StatefulWidget {
  const CtBookingsScreen({super.key});

  @override
  State<CtBookingsScreen> createState() => _CtBookingsScreenState();
}

class _CtBookingsScreenState extends State<CtBookingsScreen> {
  List<CtBookingModel> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await CtService.instance.getMyBookings();
      setState(() { _bookings = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'confirmed':
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmé';
      case 'completed': return 'Terminé';
      case 'cancelled': return 'Annulé';
      default: return status;
    }
  }

  String _transportLabel(String mode) {
    switch (mode) {
      case 'self': return 'Véhicule personnel';
      case 'tow': return 'Remorquage';
      case 'driver': return 'Chauffeur';
      default: return mode;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes rendez-vous CT',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Réessayer', style: TextStyle(color: Colors.white))),
                  ]))
              : _bookings.isEmpty
                  ? const Center(
                      child: Text('Aucun rendez-vous trouvé',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings.length,
                        itemBuilder: (_, i) => _BookingCard(
                          booking: _bookings[i],
                          statusColor: _statusColor(_bookings[i].status),
                          statusLabel: _statusLabel(_bookings[i].status),
                          transportLabel: _transportLabel(_bookings[i].transportMode),
                          formatDate: _formatDate,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) =>
                                  CtBookingDetailScreen(bookingId: _bookings[i].id))),
                        ),
                      )),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final CtBookingModel booking;
  final Color statusColor;
  final String statusLabel;
  final String transportLabel;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap;

  const _BookingCard({
    required this.booking,
    required this.statusColor,
    required this.statusLabel,
    required this.transportLabel,
    required this.formatDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(booking.reference,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withAlpha(80)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 10),
          _Row(icon: Icons.directions_car_outlined, text: booking.vehicle.registrationNumber),
          const SizedBox(height: 4),
          _Row(icon: Icons.location_on_outlined, text: booking.center.name),
          const SizedBox(height: 4),
          _Row(
            icon: Icons.calendar_today_outlined,
            text: formatDate(booking.slotStartsAt),
          ),
          const SizedBox(height: 4),
          _Row(icon: Icons.local_taxi_outlined, text: transportLabel),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${booking.totalAmount.toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.primary)),
            Text(booking.paymentStatus,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: AppColors.textMuted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}
