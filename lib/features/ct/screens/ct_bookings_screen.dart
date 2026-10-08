// lib/features/ct/screens/ct_bookings_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Liste des rendez-vous CT du client.
//
// ⚠️ Contient l'accès au QR code (via CtBookingDetailScreen).
// C'est ici que le client retrouve ses QR codes pour les présenter au centre.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/ct_service.dart';
import '../../../shared/utils/date_filter_utils.dart';
import '../../../shared/widgets/date_range_filter.dart';
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

  /// Filtre période sélectionné (S14).
  DateFilter _selectedFilter = DateFilter.all;

  /// Liste filtrée par période sélectionnée.
  List<CtBookingModel> get _filteredBookings => _bookings
      .where((b) => matchesDateFilter(b.slotStartsAt, _selectedFilter))
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await CtService.instance.getMyBookings();
      // Tri : les bookings à venir en premier, puis par date décroissante
      list.sort((a, b) {
        final now = DateTime.now();
        final aFuture = a.slotStartsAt.isAfter(now);
        final bFuture = b.slotStartsAt.isAfter(now);
        if (aFuture && !bFuture) return -1;
        if (!aFuture && bFuture) return 1;
        return b.slotStartsAt.compareTo(a.slotStartsAt);
      });
      if (!mounted) return;
      setState(() { _bookings = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Mes rendez-vous${_bookings.isNotEmpty ? ' (${_bookings.length})' : ''}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Column(
        children: [
          // Filtre période (S14)
          DateRangeFilter(
            selected: _selectedFilter,
            onChanged: (f) => setState(() => _selectedFilter = f),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? _buildError()
                    : _filteredBookings.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredBookings.length,
                              itemBuilder: (_, i) => _BookingCard(
                                booking: _filteredBookings[i],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CtBookingDetailScreen(
                                      bookingId: _filteredBookings[i].id,
                                    ),
                                  ),
                                ).then((_) => _load()), // Refresh au retour
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Réessayer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined,
              size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Aucun rendez-vous',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vos rendez-vous de contrôle technique\napparaîtront ici après paiement.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte d'un booking
// ─────────────────────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final CtBookingModel booking;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy', 'fr');
    final timeFmt = DateFormat('HH:mm');

    // Détermine l'état visuel du booking
    final now = DateTime.now();
    final isFuture = booking.slotStartsAt.isAfter(now);
    final hoursSince = now.difference(booking.slotStartsAt).inHours;
    final isWithin24h = hoursSince >= 0 && hoursSince < 24;

    // Le QR est-il encore utile ?
    final qrAvailable =
        booking.qrToken != null && (isFuture || isWithin24h);

    // Label et couleur
    String statusLabel;
    Color statusColor;
    if (booking.isCancelled) {
      statusLabel = 'Annulé';
      statusColor = AppColors.error;
    } else if (booking.isCompleted) {
      statusLabel = 'Terminé';
      statusColor = AppColors.textMuted;
    } else if (isWithin24h) {
      statusLabel = 'Aujourd\'hui';
      statusColor = AppColors.primary;
    } else if (isFuture) {
      statusLabel = 'À venir';
      statusColor = AppColors.success;
    } else {
      statusLabel = 'Passé';
      statusColor = AppColors.textMuted;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : référence + statut
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.reference,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Date + heure
            _Row(
              icon: Icons.calendar_today_outlined,
              text: '${dateFmt.format(booking.slotStartsAt)} à ${timeFmt.format(booking.slotStartsAt)}',
            ),
            const SizedBox(height: 6),
            _Row(
              icon: Icons.directions_car_outlined,
              text: booking.vehicle.registrationNumber,
            ),
            const SizedBox(height: 6),
            _Row(
              icon: Icons.location_on_outlined,
              text: booking.center.name,
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Pied : montant + action QR
            Row(
              children: [
                Text(
                  '${booking.totalAmount.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                if (qrAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_rounded,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'Voir QR',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (booking.isCancelled)
                  Text(
                    'Annulé',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  )
                else
                  Text(
                    'QR expiré',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
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
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
