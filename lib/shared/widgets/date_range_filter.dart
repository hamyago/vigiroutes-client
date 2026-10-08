// lib/shared/widgets/date_range_filter.dart
// ─────────────────────────────────────────────────────────────────────────────
// Filtre de période réutilisable (S14).
// Affiche 4 chips horizontaux : Tout / Aujourd'hui / Cette semaine / Ce mois.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

enum DateFilter {
  all('Tout'),
  today('Aujourd\'hui'),
  week('Cette semaine'),
  month('Ce mois');

  final String label;
  const DateFilter(this.label);
}

class DateRangeFilter extends StatelessWidget {
  final DateFilter selected;
  final ValueChanged<DateFilter> onChanged;

  const DateRangeFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.background,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: DateFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = DateFilter.values[i];
          final isSelected = f == selected;
          return ChoiceChip(
            label: Text(
              f.label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            selected: isSelected,
            onSelected: (_) => onChanged(f),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surface,
            showCheckmark: false,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }
}
