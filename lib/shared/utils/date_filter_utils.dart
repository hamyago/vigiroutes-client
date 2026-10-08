// lib/shared/utils/date_filter_utils.dart
// ─────────────────────────────────────────────────────────────────────────────
// Utilitaire de filtrage par période (S14).
// Utilisé par tous les écrans à liste (interventions, devis, RDV, commandes).
// ─────────────────────────────────────────────────────────────────────────────

import '../widgets/date_range_filter.dart';

/// Vérifie si une date correspond au filtre sélectionné.
///
/// Règles :
/// - all    : toujours vrai
/// - today  : itemDate >= aujourd'hui 00:00
/// - week   : itemDate >= lundi de cette semaine 00:00
/// - month  : itemDate >= 1er du mois en cours 00:00
bool matchesDateFilter(DateTime itemDate, DateFilter filter) {
  if (filter == DateFilter.all) return true;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (filter) {
    case DateFilter.all:
      return true;
    case DateFilter.today:
      return !itemDate.isBefore(today);
    case DateFilter.week:
      // Lundi de cette semaine (weekday : lundi=1, dimanche=7)
      final weekday = now.weekday;
      final monday = today.subtract(Duration(days: weekday - 1));
      return !itemDate.isBefore(monday);
    case DateFilter.month:
      final firstOfMonth = DateTime(now.year, now.month, 1);
      return !itemDate.isBefore(firstOfMonth);
  }
}
