// lib/features/ct/screens/ct_centers_marketplace_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Marketplace des centres CT (S22.2).
//
// Liste enrichie des centres avec :
//   - tri (distance | rating | price)
//   - position GPS de l'utilisateur (pour la distance)
//   - sélection d'un centre (retourne l'ID via Navigator.pop)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/ct_center_marketplace_model.dart';
import '../../../core/services/ct_service.dart';
import '../../../core/services/location_service.dart';
import '../widgets/ct_center_card.dart';

enum _SortOption {
  distance('Distance', 'distance'),
  rating('Note', 'rating'),
  price('Prix', 'price');

  final String label;
  final String apiValue;
  const _SortOption(this.label, this.apiValue);
}

class CtCentersMarketplaceScreen extends StatefulWidget {
  final String? selectedCenterId;

  const CtCentersMarketplaceScreen({
    super.key,
    this.selectedCenterId,
  });

  @override
  State<CtCentersMarketplaceScreen> createState() =>
      _CtCentersMarketplaceScreenState();
}

class _CtCentersMarketplaceScreenState
    extends State<CtCentersMarketplaceScreen> {
  List<CtCenterMarketplaceModel> _centers = [];
  bool _loading = true;
  String? _error;
  _SortOption _sort = _SortOption.distance;

  double? _userLat;
  double? _userLng;

  @override
  void initState() {
    super.initState();
    _loadWithPosition();
  }

  Future<void> _loadWithPosition() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // 1) Récupérer la position (best-effort)
    try {
      final pos = await LocationService().getCurrentPosition();
      if (pos != null) {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      }
    } catch (_) {
      // On continue sans position (tri par nom par défaut)
    }

    await _loadCenters();
  }

  Future<void> _loadCenters() async {
    try {
      final list = await CtService.instance.getCentersMarketplace(
        lat: _userLat,
        lng: _userLng,
        sort: _sort.apiValue,
      );
      if (!mounted) return;
      setState(() {
        _centers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSortChanged(_SortOption s) {
    if (_sort == s) return;
    setState(() => _sort = s);
    _loadCenters();
  }

  void _onSelectCenter(CtCenterMarketplaceModel center) {
    Navigator.of(context).pop(center);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Choisir un centre CT',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filtres de tri
          _buildSortChips(),

          // Indicateur position
          if (_userLat != null && _userLng != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.my_location,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Distance calculée depuis votre position',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Liste
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSortChips() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _SortOption.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final opt = _SortOption.values[i];
          final selected = _sort == opt;
          return GestureDetector(
            onTap: () => _onSortChanged(opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                opt.label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              'Erreur : $_error',
              style: TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWithPosition,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    if (_centers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Aucun centre disponible',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadWithPosition,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _centers.length,
        itemBuilder: (_, i) {
          final c = _centers[i];
          return CtCenterCard(
            center: c,
            isSelected: c.id == widget.selectedCenterId,
            onTap: () => _onSelectCenter(c),
          );
        },
      ),
    );
  }
}
