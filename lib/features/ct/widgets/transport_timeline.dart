// lib/features/ct/widgets/transport_timeline.dart
// Widget d'affichage du suivi transport unifié (S17.3).
//
// Timeline unique comprenant :
//   - Les étapes de transport (pickup → centre → retour → livraison)
//   - Les étapes de contrôle technique (arrivée, inspection, résultat)
//   - La notation du transporteur (S17.3)
//
// La logique d'état est basée sur les TIMESTAMPS (pas sur un index) :
//   - Done     : timestamp rempli
//   - Current  : premier timestamp vide (après au moins un rempli)
//   - Pending  : timestamp vide (aucun précédent rempli)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';

class TransportTimeline extends StatelessWidget {
  final CtBookingModel booking;

  /// Timestamp de la notation du transporteur (null si pas encore noté).
  final DateTime? ratingCreatedAt;

  /// Note du transporteur (1-5), null si pas encore noté.
  final int? rating;

  /// Callback pour l'action "Noter le transporteur".
  final VoidCallback? onRatePressed;

  const TransportTimeline({
    super.key,
    required this.booking,
    this.ratingCreatedAt,
    this.rating,
    this.onRatePressed,
  });

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
          _buildHeader(),
          const SizedBox(height: 16),
          if (booking.transporterStatus == null)
            _buildNotAssigned()
          else
            _buildSteps(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          booking.transportMode == 'tow'
              ? Icons.local_shipping_rounded
              : Icons.person_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
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
        ),
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
    // Construire les étapes dynamiquement
    final steps = <_TimelineStep>[
      // ── Transport ─────────────────────────────────────────────────
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
      // ── Contrôle technique (S17.3) ────────────────────────────────
      _TimelineStep(
        label: 'Arrivé au centre (CT)',
        time: booking.arrivedAt,
        icon: Icons.place_rounded,
      ),
      _TimelineStep(
        label: 'Inspection démarrée',
        time: booking.inspectionStartedAt,
        icon: Icons.build_rounded,
      ),
      _TimelineStep(
        label: 'Résultat disponible',
        time: booking.vtCompletedAt,
        icon: Icons.assignment_turned_in_rounded,
        resultBadge: booking.vtResult,
      ),
      // ── Retour + livraison ────────────────────────────────────────
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
      _TimelineStep(
        label: 'Livraison validée',
        time: booking.transporterCompletedAt,
        icon: Icons.verified_rounded,
      ),
      // ── Notation transporteur (S17.3) ─────────────────────────────
      _TimelineStep(
        label: rating != null ? 'Transporteur noté' : 'Noter le transporteur',
        time: ratingCreatedAt,
        icon: Icons.star_rounded,
        rating: rating,
        isAction: rating == null && onRatePressed != null,
        onActionTap: onRatePressed,
      ),
    ];

    // Déterminer l'index actuel :
    // - Le premier step sans time mais dont au moins un précédent est rempli
    // - Si tous sont remplis → dernier index
    int currentIndex = -1;
    for (int i = 0; i < steps.length; i++) {
      if (steps[i].time == null) {
        currentIndex = i;
        break;
      }
    }
    // Si tous les timestamps sont remplis, currentIndex = dernier
    if (currentIndex == -1) currentIndex = steps.length - 1;

    return Column(
      children: List.generate(steps.length, (i) {
        final isDone = steps[i].time != null;
        final isCurrent = i == currentIndex;
        return _TimelineRow(
          step: steps[i],
          isDone: isDone,
          isCurrent: isCurrent,
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
  final String? resultBadge;        // FAVORABLE / DÉFAVORABLE
  final int? rating;                // 1-5 (si noté)
  final bool isAction;              // true si c'est un bouton d'action
  final VoidCallback? onActionTap;  // callback si isAction

  _TimelineStep({
    required this.label,
    required this.time,
    required this.icon,
    this.resultBadge,
    this.rating,
    this.isAction = false,
    this.onActionTap,
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
    final fmt = DateFormat('dd/MM HH:mm', 'fr');

    final circleColor = isDone
        ? AppColors.primary
        : isCurrent
            ? AppColors.primary.withValues(alpha: 0.4)
            : AppColors.border;

    // État spécial : étape "noter" (action disponible)
    final isPendingAction = step.isAction && !isDone;

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
                      : isPendingAction
                          ? Colors.amber.withValues(alpha: 0.15)
                          : isCurrent
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPendingAction ? Colors.amber : circleColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isDone ? Icons.check : step.icon,
                  size: 14,
                  color: isDone
                      ? Colors.white
                      : isPendingAction
                          ? Colors.amber.shade700
                          : circleColor,
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
            child: _buildContent(context, fmt, isPendingAction),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, DateFormat fmt, bool isPendingAction) {
    // Cas 1 : résultat CT avec badge
    if (step.resultBadge != null && isDone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                fmt.format(step.time!),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildResultBadge(step.resultBadge!),
        ],
      );
    }

    // Cas 2 : notation affichée (étoiles)
    if (step.rating != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.label,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (step.time != null)
                Text(
                  fmt.format(step.time!),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          _buildStars(step.rating!),
        ],
      );
    }

    // Cas 3 : action (bouton "Noter le transporteur")
    if (isPendingAction) {
      return Row(
        children: [
          Expanded(
            child: Text(
              step.label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: step.onActionTap,
            icon: const Icon(Icons.star_outline_rounded, size: 16),
            label: const Text('Noter', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.amber.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      );
    }

    // Cas 4 : ligne standard
    return Row(
      children: [
        Expanded(
          child: Text(
            step.label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
              color:
                  isDone ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        if (step.time != null)
          Text(
            fmt.format(step.time!),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              color: isDone ? AppColors.primary : AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildResultBadge(String result) {
    final r = result.toLowerCase();
    final isFavorable = r.contains('favorable') && !r.contains('défavorable');
    final color = isFavorable ? AppColors.success : AppColors.error;
    final label = isFavorable ? 'FAVORABLE' : 'DÉFAVORABLE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStars(int rating) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: Colors.amber.shade700,
        );
      }),
    );
  }
}
