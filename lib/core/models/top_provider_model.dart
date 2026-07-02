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
        rating:              _num(json['rating']),
        ratingCount:         _num(json['rating_count']).toInt(),
        totalInterventions:  _num(json['total_interventions']).toInt(),
        phone:               json['phone'] as String?,
      );
}

// Conversion tolérante : Laravel sérialise parfois les colonnes
// DECIMAL sous forme de chaînes ("4.50") plutôt que de nombres JSON.
double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
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
