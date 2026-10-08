// lib/features/ct/widgets/transport_timeline.dart
// Widget d'affichage du suivi transport dans l'app Client.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';

class TransportTimeline extends StatelessWidget {
  final CtBookingModel booking;

  const TransportTimeline({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    if (!booking.hasTransportTracking) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                booking.transportMode == 'tow'
                    ? Icons.local_shipping_rounded
                    : Icons.person_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                booking.transportMode == 'tow'
                    ? 'Suivi du remorquage'
                    : 'Suivi du chauffeur',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  booking.transportStepLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (booking.transporterStatus == null)
            _buildNotAssigned()
          else
            _buildSteps(),
        ],
      ),
    );
  }

  Widget _buildNotAssigned() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aucun transporteur assigné pour le moment. Vous serez notifié dès qu\'un transporteur prendra en charge votre véhicule.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    final steps = [
      _TimelineStep(
        label: 'Transporteur en route',
        time: booking.transporterEnRouteAt,
        icon: Icons.directions_car_rounded,
      ),
      _TimelineStep(
        label: 'Véhicule récupéré',
        time: booking.transporterPickedUpAt,
        icon: Icons.inventory_2_outlined,
      ),
      _TimelineStep(
        label: 'Arrivé au centre',
        time: booking.transporterDeliveredAt,
        icon: Icons.business_rounded,
      ),
      _TimelineStep(
        label: 'Retour en cours',
        time: booking.transporterReturnStartedAt,
        icon: Icons.undo_rounded,
      ),
      _TimelineStep(
        label: 'Véhicule livré',
        time: booking.transporterReturnedAt,
        icon: Icons.check_circle_rounded,
      ),
      // S13.6.2 : étape finale (signature client)
      _TimelineStep(
        label: 'Livraison validée',
        time: booking.transporterCompletedAt,
        icon: Icons.verified_rounded,
      ),
    ];

    final currentIndex = booking.transportStepIndex;

    return Column(
      children: List.generate(steps.length, (i) {
        return _TimelineRow(
          step: steps[i],
          isDone: i <= currentIndex,
          isCurrent: i == currentIndex,
          isLast: i == steps.length - 1,
        );
      }),
    );
  }
}

class _TimelineStep {
  final String label;
  final DateTime? time;
  final IconData icon;

  _TimelineStep({
    required this.label,
    required this.time,
    required this.icon,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineStep step;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  const _TimelineRow({
    required this.step,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm', 'fr');

    final circleColor = isDone
        ? AppColors.primary
        : isCurrent
            ? AppColors.primary.withValues(alpha: 0.4)
            : AppColors.border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.primary
                      : isCurrent
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: circleColor, width: 2),
                ),
                child: Icon(
                  isDone ? Icons.check : step.icon,
                  size: 14,
                  color: isDone ? Colors.white : circleColor,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 32,
                  color: isDone ? AppColors.primary : AppColors.border,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    step.label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight:
                          isDone ? FontWeight.w600 : FontWeight.normal,
                      color: isDone
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (step.time != null)
                  Text(
                    fmt.format(step.time!),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color:
                          isDone ? AppColors.primary : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
