// Conversions tolérantes : les API Laravel renvoient souvent les décimaux
// (latitude, rating, etc.) sous forme de CHAÎNES. On accepte String OU nombre.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

// ── UserModel ─────────────────────────────────────────────────────────────────

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;
  final String? fcmToken;
  final bool isActive;
  final String subscriptionPlan;
  final DateTime? subscriptionExpiresAt;
  final int totalInterventions;
  final double rating;
  final int ratingCount;
  final List<dynamic> vehicles;
  final String? whatsapp;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    this.fcmToken,
    required this.isActive,
    required this.subscriptionPlan,
    this.subscriptionExpiresAt,
    required this.totalInterventions,
    this.rating = 5.0,
    this.ratingCount = 0,
    this.vehicles = const [],
    this.whatsapp,
  });

  DateTime? get subscriptionExpiry => subscriptionExpiresAt;

  /// VigiRoutes Client est désormais 100% gratuit pour tous les
  /// utilisateurs : liste complète des prestataires et demandes
  /// illimitées sans condition. Conservé à `true` plutôt que supprimé
  /// pour ne pas casser un appel existant ailleurs dans le code qui
  /// vérifierait encore ce champ.
  bool get hasSubscription => true;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:                    json['id'] as String,
        name:                  json['name'] as String,
        phone:                 json['phone'] as String,
        email:                 json['email'] as String?,
        photoUrl:              json['photo_url'] as String?,
        fcmToken:              json['fcm_token'] as String?,
        isActive:              json['is_active'] as bool? ?? true,
        subscriptionPlan:      json['subscription_plan'] as String? ?? 'none',
        subscriptionExpiresAt: json['subscription_expires_at'] != null
            ? DateTime.parse(json['subscription_expires_at'] as String)
            : null,
        totalInterventions:    json['total_interventions'] as int? ?? 0,
        rating:                (json['rating'] as num?)?.toDouble() ?? 5.0,
        ratingCount:           json['rating_count'] as int? ?? 0,
        vehicles:              (json['vehicles'] as List<dynamic>?) ?? [],
        whatsapp:              json['whatsapp'] as String?,
      );
}

// ── ProviderModel ─────────────────────────────────────────────────────────────

class ProviderModel {
  final String id;
  final String name;
  final String phone;
  final String? photoUrl;
  final String? fcmToken;
  final double latitude;
  final double longitude;
  final bool isAvailable;
  final bool isActive;
  final bool isVerified;
  final List<String> serviceTypes;
  final double rating;
  final int ratingCount;
  final double totalEarnings;
  final int totalInterventions;
  double? distanceKm;

  ProviderModel({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl,
    this.fcmToken,
    required this.latitude,
    required this.longitude,
    required this.isAvailable,
    required this.isActive,
    required this.isVerified,
    required this.serviceTypes,
    required this.rating,
    required this.ratingCount,
    required this.totalEarnings,
    required this.totalInterventions,
    this.distanceKm,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) => ProviderModel(
        id:                 json['id'] as String,
        name:               json['name'] as String,
        phone:              json['phone'] as String? ?? '',
        photoUrl:           json['photo_url'] as String?,
        fcmToken:           json['fcm_token'] as String?,
        latitude:           _toDouble(json['latitude']),
        longitude:          _toDouble(json['longitude']),
        isAvailable:        json['is_available'] as bool? ?? true,
        isActive:           json['is_active'] as bool? ?? true,
        isVerified:         json['is_verified'] as bool? ?? false,
        serviceTypes:       (json['service_types'] as List?)
                                ?.map((e) => e as String).toList() ?? [],
        rating:             _toDouble(json['rating']),
        ratingCount:        _toInt(json['rating_count']),
        totalEarnings:      _toDouble(json['total_earnings']),
        totalInterventions: _toInt(json['total_interventions']),
        distanceKm:         json['distance_km'] == null
                                ? null
                                : _toDouble(json['distance_km']),
      );
}

// ── InterventionModel ─────────────────────────────────────────────────────────

class InterventionModel {
  final String id;
  final String userId;
  final String? providerId;
  final String serviceTypeId;
  final String serviceTypeName;
  final String status;
  final double userLatitude;
  final double userLongitude;
  final String? userAddress;
  final double? providerLatitude;
  final double? providerLongitude;
  final double distanceKm;
  final double totalPrice;
  final double commission;
  final String paymentMethod;
  final String paymentStatus;
  final ProviderModel? provider;
  final String? providerName;
  final String? providerPhone;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;

  const InterventionModel({
    required this.id,
    required this.userId,
    this.providerId,
    required this.serviceTypeId,
    required this.serviceTypeName,
    required this.status,
    required this.userLatitude,
    required this.userLongitude,
    this.userAddress,
    this.providerLatitude,
    this.providerLongitude,
    required this.distanceKm,
    required this.totalPrice,
    required this.commission,
    required this.paymentMethod,
    required this.paymentStatus,
    this.provider,
    this.providerName,
    this.providerPhone,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
  });

  bool get isActive     => status != 'completed' && status != 'cancelled';
  bool get isPending    => status == 'pending' || status == 'dispatching';
  bool get isAccepted   => status == 'accepted';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted  => status == 'completed';
  bool get isCancelled  => status == 'cancelled';

  String? get dispatchedProviderId => providerId;

  factory InterventionModel.fromJson(Map<String, dynamic> json) {
    final providerJson = json['provider'] as Map<String, dynamic>?;
    return InterventionModel(
      id:               json['id'] as String,
      userId:           json['user_id'] as String,
      providerId:       json['provider_id'] as String?,
      serviceTypeId:    json['service_type_id'] as String? ?? '',
      serviceTypeName:  json['service_type_name'] as String? ?? '',
      status:           json['status'] as String? ?? 'pending',
      userLatitude:     (json['user_latitude'] as num?)?.toDouble() ?? 0,
      userLongitude:    (json['user_longitude'] as num?)?.toDouble() ?? 0,
      userAddress:      json['user_address'] as String?,
      providerLatitude: (json['provider_latitude'] as num?)?.toDouble(),
      providerLongitude:(json['provider_longitude'] as num?)?.toDouble(),
      distanceKm:       (json['distance_km'] as num?)?.toDouble() ?? 0,
      totalPrice:       (json['total_price'] as num?)?.toDouble() ?? 0,
      commission:       (json['commission'] as num?)?.toDouble() ?? 0,
      paymentMethod:    json['payment_method'] as String? ?? 'cash',
      paymentStatus:    json['payment_status'] as String? ?? 'pending',
      provider: providerJson != null ? ProviderModel.fromJson(providerJson) : null,
      providerName:     json['provider_name'] as String?
                            ?? providerJson?['name'] as String?,
      providerPhone:    json['provider_phone'] as String?
                            ?? providerJson?['phone'] as String?,
      createdAt:        DateTime.parse(json['created_at'] as String),
      acceptedAt:       json['accepted_at'] != null
                            ? DateTime.parse(json['accepted_at'] as String) : null,
      completedAt:      json['completed_at'] != null
                            ? DateTime.parse(json['completed_at'] as String) : null,
    );
  }

  InterventionModel copyWithWs(Map<String, dynamic> data) =>
      InterventionModel.fromJson({...toJson(), ...data});

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'provider_id': providerId,
    'service_type_id': serviceTypeId, 'service_type_name': serviceTypeName,
    'status': status, 'user_latitude': userLatitude, 'user_longitude': userLongitude,
    'user_address': userAddress, 'provider_latitude': providerLatitude,
    'provider_longitude': providerLongitude, 'distance_km': distanceKm,
    'total_price': totalPrice, 'commission': commission,
    'payment_method': paymentMethod, 'payment_status': paymentStatus,
    'created_at': createdAt.toIso8601String(),
  };
}

// ── ReviewModel ───────────────────────────────────────────────────────────────

class ReviewModel {
  final String id;
  final String interventionId;
  final String userId;
  final String providerId;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.interventionId,
    required this.userId,
    required this.providerId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id:             json['id'] as String,
        interventionId: json['intervention_id'] as String,
        userId:         json['user_id'] as String,
        providerId:     json['provider_id'] as String,
        rating:         (json['rating'] as num).toDouble(),
        comment:        json['comment'] as String?,
        createdAt:      DateTime.parse(json['created_at'] as String),
      );
}

// ── VehicleModel ──────────────────────────────────────────────────────────────

class VehicleModel {
  final String id;
  final String userId;
  final String brand;
  final String model;
  final String plate;
  final String? color;
  final int? year;

  const VehicleModel({
    required this.id,
    required this.userId,
    required this.brand,
    required this.model,
    required this.plate,
    this.color,
    this.year,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
        id:     json['id'] as String,
        userId: json['user_id'] as String,
        brand:  json['brand'] as String,
        model:  json['model'] as String,
        plate:  json['plate'] as String,
        color:  json['color'] as String?,
        year:   json['year'] as int?,
      );

  Map<String, dynamic> toMap() => {
    'id': id, 'brand': brand, 'model': model,
    'plate': plate, 'color': color, 'year': year,
  };

  Map<String, dynamic> toJson() => toMap();
}
