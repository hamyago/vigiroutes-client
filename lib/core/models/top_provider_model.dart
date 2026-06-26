/// Représente un prestataire dans le classement "top 5" d'une ville,
/// reçu via la notification push city_welcome.
class TopProviderModel {
  final String id;
  final String name;
  final String? photoUrl;
  final double rating;
  final int ratingCount;
  final int totalInterventions;
  final String? phone;

  const TopProviderModel({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.rating,
    required this.ratingCount,
    required this.totalInterventions,
    this.phone,
  });

  factory TopProviderModel.fromJson(Map<String, dynamic> json) =>
      TopProviderModel(
        id:                  json['id'] as String,
        name:                json['name'] as String,
        photoUrl:            json['photo_url'] as String?,
        rating:              (json['rating'] as num?)?.toDouble() ?? 0,
        ratingCount:         (json['rating_count'] as num?)?.toInt() ?? 0,
        totalInterventions:  (json['total_interventions'] as num?)?.toInt() ?? 0,
        phone:               json['phone'] as String?,
      );
}

/// Secteur avec son libellé d'affichage et son émoji, dans l'ordre
/// d'affichage souhaité dans l'écran de bienvenue.
enum ProviderSector {
  mecanicien('mecanicien', 'Mécaniciens', '🔧'),
  remorqueur('remorqueur', 'Remorqueurs', '🚛'),
  vulcanisateur('vulcanisateur', 'Vulcanisateurs', '🔩'),
  electricienAuto('electricien_auto', 'Électriciens auto', '⚡');

  final String apiValue;
  final String label;
  final String icon;

  const ProviderSector(this.apiValue, this.label, this.icon);

  static ProviderSector? fromApiValue(String value) =>
      ProviderSector.values.where((s) => s.apiValue == value).firstOrNull;
}
