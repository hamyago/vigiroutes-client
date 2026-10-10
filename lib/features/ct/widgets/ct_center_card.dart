// lib/features/ct/widgets/ct_center_card.dart
// ─────────────────────────────────────────────────────────────────────────────
// Carte d'affichage d'un centre CT dans le marketplace (S22.2).
//
// Affiche :
//   - Nom + opérateur
//   - Distance (si dispo)
//   - Note moyenne + nb d'avis (si dispo)
//   - Prix moyen + durée moyenne (si dispo)
//   - Adresse + ville
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/ct_center_marketplace_model.dart';

class CtCenterCard extends StatelessWidget {
  final CtCenterMarketplaceModel center;
  final bool isSelected;
  final VoidCallback? onTap;

  const CtCenterCard({
    super.key,
    required this.center,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête : nom + badge "selected"
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        center.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (center.operatorName != null)
                        Text(
                          center.operatorName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: AppColors.primary, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Sélectionné',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Rating + distance
            Row(
              children: [
                if (center.hasRating) ...[
                  _buildStars(center.avgRating!),
                  const SizedBox(width: 6),
                  Text(
                    center.avgRating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${center.reviewsCount} avis)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ] else
                  Text(
                    'Aucun avis',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textMuted,
                    ),
                  ),
                const Spacer(),
                if (center.hasDistance) ...[
                  Icon(Icons.location_on_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    center.distanceLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Adresse
            Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${center.city}${center.address != null ? ' · ${center.address}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Prix + durée
            if (center.hasPrice || center.hasDuration) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (center.hasPrice) ...[
                      Icon(Icons.payments_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        center.priceLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (center.hasPrice && center.hasDuration)
                      const SizedBox(width: 16),
                    if (center.hasDuration) ...[
                      Icon(Icons.schedule,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        center.durationLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          filled
              ? Icons.star_rounded
              : half
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          size: 14,
          color: Colors.amber.shade700,
        );
      }),
    );
  }
}
