// lib/core/models/ct_center_marketplace_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Modèle enrichi d'un centre CT pour le marketplace (S22.2).
//
// Contient les infos de base + les agrégats calculés côté backend :
//   - distance depuis la position de l'utilisateur
//   - note moyenne + nb d'avis
//   - prix moyen + durée moyenne
// ─────────────────────────────────────────────────────────────────────────────

class CtCenterMarketplaceModel {
  final String id;
  final String name;
  final String? operatorName;
  final String type;
  final String? address;
  final String city;
  final double? latitude;
  final double? longitude;
  final String? contactPhone;
  final String? photoUrl;
  final String? description;

  final double? distanceKm;
  final double? avgRating;
  final int reviewsCount;
  final double? avgPrice;
  final double? avgDurationHours;

  const CtCenterMarketplaceModel({
    required this.id,
    required this.name,
    this.operatorName,
    required this.type,
    this.address,
    required this.city,
    this.latitude,
    this.longitude,
    this.contactPhone,
    this.photoUrl,
    this.description,
    this.distanceKm,
    this.avgRating,
    this.reviewsCount = 0,
    this.avgPrice,
    this.avgDurationHours,
  });

  bool get hasRating => avgRating != null && reviewsCount > 0;
  bool get hasPrice => avgPrice != null;
  bool get hasDuration => avgDurationHours != null;
  bool get hasDistance => distanceKm != null;

  /// Formate la distance pour l'affichage.
  String get distanceLabel {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  /// Formate le prix moyen.
  String get priceLabel {
    if (avgPrice == null) return '—';
    return '${avgPrice!.toStringAsFixed(0)} FCFA';
  }

  /// Formate la durée moyenne.
  String get durationLabel {
    if (avgDurationHours == null) return '—';
    if (avgDurationHours! < 1) {
      return '${(avgDurationHours! * 60).toStringAsFixed(0)} min';
    }
    return '${avgDurationHours!.toStringAsFixed(1)} h';
  }

  factory CtCenterMarketplaceModel.fromJson(Map<String, dynamic> json) {
    return CtCenterMarketplaceModel(
      id:               (json['id'] ?? '').toString(),
      name:             (json['name'] ?? '').toString(),
      operatorName:     json['operator_name']?.toString(),
      type:             (json['type'] ?? 'fixed').toString(),
      address:          json['address']?.toString(),
      city:             (json['city'] ?? '').toString(),
      latitude:         (json['latitude'] as num?)?.toDouble(),
      longitude:        (json['longitude'] as num?)?.toDouble(),
      contactPhone:     json['contact_phone']?.toString(),
      photoUrl:         json['photo_url']?.toString(),
      description:      json['description']?.toString(),
      distanceKm:       (json['distance_km'] as num?)?.toDouble(),
      avgRating:        (json['avg_rating'] as num?)?.toDouble(),
      reviewsCount:     (json['reviews_count'] as num?)?.toInt() ?? 0,
      avgPrice:         (json['avg_price'] as num?)?.toDouble(),
      avgDurationHours: (json['avg_duration_hours'] as num?)?.toDouble(),
    );
  }
}
