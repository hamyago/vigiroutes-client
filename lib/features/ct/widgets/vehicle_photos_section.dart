// lib/features/ct/widgets/vehicle_photos_section.dart
// ─────────────────────────────────────────────────────────────────────────────
// Section d'affichage des photos du véhicule (S16.2).
//
// Affiche 2 blocs :
//   - Photos avant transport (pickup)
//   - Photos après livraison (delivery)
//
// Chaque bloc contient 4 miniatures (avant / arrière / gauche / droite).
// Tap sur une miniature → viewer plein écran avec swipe.
//
// Se masque automatiquement si aucune photo n'est disponible.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/ct_service.dart';
import 'photo_viewer.dart';

/// Base URL pour les images (les URLs renvoyées par l'API sont relatives).
const String _kImageBaseUrl = 'https://api.vigiroutes.com';

class VehiclePhotosSection extends StatefulWidget {
  final String bookingId;
  final String? transporterStatus;

  const VehiclePhotosSection({
    super.key,
    required this.bookingId,
    this.transporterStatus,
  });

  @override
  State<VehiclePhotosSection> createState() => _VehiclePhotosSectionState();
}

class _VehiclePhotosSectionState extends State<VehiclePhotosSection> {
  List<Map<String, dynamic>> _pickup = [];
  List<Map<String, dynamic>> _delivery = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VehiclePhotosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recharger si le statut change (photos ajoutées entre-temps)
    if (oldWidget.transporterStatus != widget.transporterStatus) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final data = await CtService.instance.getMissionPhotos(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _pickup = (data['pickup_photos'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            [];
        _delivery = (data['delivery_photos'] as List?)
                ?.map((e) => (e as Map).cast<String, dynamic>())
                .toList() ??
            [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tant qu'on charge, on n'affiche rien (évite un flash)
    if (_loading) return const SizedBox.shrink();

    // Aucune photo → masquer complètement
    if (_pickup.isEmpty && _delivery.isEmpty) {
      return const SizedBox.shrink();
    }

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
              Icon(Icons.photo_camera_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Photos du véhicule',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pickup.isNotEmpty) ...[
            _buildBlock(context, 'Avant transport', _pickup, 'pickup'),
            if (_delivery.isNotEmpty) const SizedBox(height: 20),
          ],
          if (_delivery.isNotEmpty)
            _buildBlock(context, 'Après livraison', _delivery, 'delivery'),
        ],
      ),
    );
  }

  Widget _buildBlock(
    BuildContext ctx,
    String title,
    List<Map<String, dynamic>> photos,
    String photoContext,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: photos.map((p) {
            final slot = (p['slot'] as String?) ?? '';
            final url = (p['url'] as String?) ?? '';
            return _buildThumbnail(
              url: '$_kImageBaseUrl$url',
              slot: slot,
              onTap: () => _openViewer(ctx, photos, photoContext, slot),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThumbnail({
    required String url,
    required String slot,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.background,
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.background,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                bottom: 2,
                left: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _slotLabel(slot),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _slotLabel(String slot) {
    switch (slot) {
      case 'front':
        return 'AV';
      case 'back':
        return 'AR';
      case 'left':
        return 'GA';
      case 'right':
        return 'DR';
      default:
        return slot.toUpperCase();
    }
  }

  void _openViewer(
    BuildContext ctx,
    List<Map<String, dynamic>> photos,
    String photoContext,
    String slot,
  ) {
    // Construire la liste des URLs pour le viewer
    final urls = photos
        .map((p) => '$_kImageBaseUrl${p['url'] ?? ''}')
        .toList();
    final index = photos.indexWhere((p) => p['slot'] == slot);

    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewer(
          urls: urls,
          initialIndex: index >= 0 ? index : 0,
          title: photoContext == 'pickup'
              ? 'Photos avant transport'
              : 'Photos après livraison',
        ),
      ),
    );
  }
}
