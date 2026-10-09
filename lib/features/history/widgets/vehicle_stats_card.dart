// lib/features/history/widgets/vehicle_stats_card.dart
// ─────────────────────────────────────────────────────────────────────────────
// Carte d'affichage des statistiques d'interventions pour un véhicule (S18).
//
// Affiche :
//   - Le total des 30 derniers jours (count + coût)
//   - La répartition par type (barres horizontales)
//   - Le total "vie entière"
//   - Les alertes de récurrence (>= 3 interventions du même type)
//
// Se charge à partir de l'ID du véhicule via CtService.getVehicleStats().
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_stats_model.dart';
import '../../../core/services/ct_service.dart';
import '../../../core/utils/price_calculator.dart';

class VehicleStatsCard extends StatefulWidget {
  final String vehicleId;

  const VehicleStatsCard({super.key, required this.vehicleId});

  @override
  State<VehicleStatsCard> createState() => _VehicleStatsCardState();
}

class _VehicleStatsCardState extends State<VehicleStatsCard> {
  VehicleStatsModel? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VehicleStatsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vehicleId != widget.vehicleId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await CtService.instance.getVehicleStats(widget.vehicleId);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final s = _stats;
    if (s == null || !s.hasData) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Icon(Icons.insights_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Statistiques — ${s.registrationNumber}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── 30 derniers jours ──────────────────────────────────────
          if (s.currentCount > 0) ...[
            _buildPeriodBlock(s),
            const SizedBox(height: 16),
          ],

          // ── Alertes ───────────────────────────────────────────────
          if (s.hasAlerts) ...[
            ...s.alerts.map((a) => _buildAlert(a)),
            const SizedBox(height: 12),
          ],

          // ── Total vie ─────────────────────────────────────────────
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.history_rounded,
                  color: AppColors.textMuted, size: 16),
              const SizedBox(width: 6),
              Text(
                'Total vie : ',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${s.lifetimeCount} interventions',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                PriceCalculator.formatFcfa(s.lifetimeCost),
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodBlock(VehicleStatsModel s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ce mois (${s.periodDays} derniers jours)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${s.currentCount} interventions',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              PriceCalculator.formatFcfa(s.currentCost),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Répartition
        ...s.byType.map((t) => _buildTypeRow(t, s.currentCount)),
      ],
    );
  }

  Widget _buildTypeRow(VehicleStatsType t, int total) {
    final ratio = total > 0 ? t.count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_typeEmoji(t.serviceTypeId)} ${t.serviceTypeName}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '×${t.count}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 70,
                child: Text(
                  PriceCalculator.formatFcfa(t.cost),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Barre horizontale
          LayoutBuilder(
            builder: (_, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 4,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    height: 4,
                    width: constraints.maxWidth * ratio,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlert(VehicleStatsAlert a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              a.message,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeEmoji(String id) {
    const icons = {
      'mechanic': '🔧',
      'towing': '🚛',
      'tire': '🔩',
      'electrical': '⚡',
      'battery': '🔋',
      'fuel': '⛽',
      'locksmith': '🔑',
      'other': '🛠️',
    };
    return icons[id] ?? '🛠️';
  }
}
