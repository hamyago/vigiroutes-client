// lib/core/models/tariff_model.dart

/// Modèle de tarification VigiRoutes.
/// Reflète la table `tariffs` côté Laravel.
///
/// Structure :
///   - frais_partenaire    : part reversée au prestataire (fixe, par service_type)
///   - frais_option_*      : supplément selon le mode de transport choisi
///   - frais_vigiRoutes    : frais de service plateforme (fixe)
///
/// Le montant total = frais_partenaire + frais_option (selon mode) + frais_vigiRoutes
class TariffModel {
  final String id;
  final String? serviceTypeSlug; // null = tarif global (CT, etc.)
  final String label;            // ex : "Dépannage", "CT", "Global"

  /// Part reversée au prestataire (FCFA)
  final int fraisPartenaire;

  /// Option 1 : le client fait venir une dépanneuse/remorquage (FCFA)
  final int fraisOptionRemorquage;

  /// Option 2 : un chauffeur est affecté pour conduire le véhicule (FCFA)
  final int fraisOptionChauffeur;

  /// Option 3 : le client se déplace par ses propres moyens (FCFA, souvent 0)
  final int fraisOptionDeplacement;

  /// Frais de service VigiRoutes (FCFA)
  final int fraisVigiRoutes;

  final bool isActive;
  final DateTime? updatedAt;

  const TariffModel({
    required this.id,
    this.serviceTypeSlug,
    required this.label,
    required this.fraisPartenaire,
    required this.fraisOptionRemorquage,
    required this.fraisOptionChauffeur,
    required this.fraisOptionDeplacement,
    required this.fraisVigiRoutes,
    this.isActive = true,
    this.updatedAt,
  });

  factory TariffModel.fromJson(Map<String, dynamic> json) => TariffModel(
        id:                      json['id'] as String,
        serviceTypeSlug:         json['service_type_slug'] as String?,
        label:                   json['label'] as String? ?? '',
        fraisPartenaire:         _toInt(json['frais_partenaire']),
        fraisOptionRemorquage:   _toInt(json['frais_option_remorquage']),
        fraisOptionChauffeur:    _toInt(json['frais_option_chauffeur']),
        fraisOptionDeplacement:  _toInt(json['frais_option_deplacement']),
        fraisVigiRoutes:         _toInt(json['frais_vigiRoutes']),
        isActive:                (json['is_active'] as bool?) ?? true,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// Calcule le frais option selon le mode de transport.
  /// [transportMode] : 'tow' | 'driver' | 'self'
  int fraisOptionPour(String transportMode) => switch (transportMode) {
        'tow'    => fraisOptionRemorquage,
        'driver' => fraisOptionChauffeur,
        _        => fraisOptionDeplacement,
      };

  /// Total = frais_partenaire + frais_option + frais_vigiRoutes
  int totalPour(String transportMode) =>
      fraisPartenaire + fraisOptionPour(transportMode) + fraisVigiRoutes;

  String fmt(int fcfa) {
    final s = fcfa.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} FCFA';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'service_type_slug': serviceTypeSlug,
        'label': label,
        'frais_partenaire': fraisPartenaire,
        'frais_option_remorquage': fraisOptionRemorquage,
        'frais_option_chauffeur': fraisOptionChauffeur,
        'frais_option_deplacement': fraisOptionDeplacement,
        'frais_vigiRoutes': fraisVigiRoutes,
        'is_active': isActive,
      };
}
