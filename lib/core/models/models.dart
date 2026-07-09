// Conversions tolérantes : les API Laravel renvoient souvent les décimaux
// (latitude, rating, etc.) sous forme de CHAÎNES. On accepte String OU nombre.
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

double? _toDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
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
        totalInterventions:    _toInt(json['total_interventions']),
        rating:                json['rating'] == null ? 5.0 : _toDouble(json['rating']),
        ratingCount:           _toInt(json['rating_count']),
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

class AssignedAssistant {
  final String name;
  final String? phone;
  final String? photoUrl;

  const AssignedAssistant({required this.name, this.phone, this.photoUrl});

  factory AssignedAssistant.fromJson(Map<String, dynamic> json) => AssignedAssistant(
        name:     (json['name'] ?? '').toString(),
        phone:    json['phone']?.toString(),
        photoUrl: json['photo_url']?.toString(),
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'phone': phone, 'photo_url': photoUrl};
}

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
  final AssignedAssistant? assignedAssistant;
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
    this.assignedAssistant,
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
      userLatitude:     _toDouble(json['user_latitude']),
      userLongitude:    _toDouble(json['user_longitude']),
      userAddress:      json['user_address'] as String?,
      providerLatitude: _toDoubleOrNull(json['provider_latitude']),
      providerLongitude:_toDoubleOrNull(json['provider_longitude']),
      distanceKm:       _toDouble(json['distance_km']),
      totalPrice:       _toDouble(json['total_price']),
      commission:       _toDouble(json['commission']),
      paymentMethod:    json['payment_method'] as String? ?? 'cash',
      paymentStatus:    json['payment_status'] as String? ?? 'pending',
      provider: providerJson != null ? ProviderModel.fromJson(providerJson) : null,
      assignedAssistant: json['assigned_assistant'] != null
          ? AssignedAssistant.fromJson(json['assigned_assistant'] as Map<String, dynamic>)
          : null,
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
    'assigned_assistant': assignedAssistant?.toJson(),
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

  // BUG CORRIGÉ : le backend renvoie from_user_id/to_user_id (jamais
  // user_id/provider_id) — ce cast échouait à CHAQUE avis, avalé
  // silencieusement par le try/catch de user_reviews_screen.dart, qui
  // affichait donc toujours "Aucun avis reçu" même quand il y en avait.
  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id:             json['id'] as String,
        interventionId: json['intervention_id'] as String,
        userId:         json['from_user_id'] as String? ??
            json['user_id'] as String? ?? '',
        providerId:     json['to_user_id'] as String? ??
            json['provider_id'] as String? ?? '',
        rating:         _toDouble(json['rating']),
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

// ── Pièces automobiles (magasins) ─────────────────────────────────────────────
// AJOUTÉ : nouvelle fonctionnalité, commande de pièces auprès des magasins
// à proximité (rayon 3 km).

class StoreProductModel {
  final String id;
  final String name;
  final double unitPrice;
  final bool isAvailable;

  const StoreProductModel({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.isAvailable,
  });

  factory StoreProductModel.fromJson(Map<String, dynamic> json) => StoreProductModel(
        id:          json['id'] as String,
        name:        json['name'] as String,
        unitPrice:   json['unit_price'] is num
            ? (json['unit_price'] as num).toDouble()
            : double.tryParse(json['unit_price'].toString()) ?? 0,
        isAvailable: json['is_available'] as bool? ?? true,
      );
}

class StoreModel {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final double rating;
  final int ratingCount;
  final List<StoreProductModel> products;

  const StoreModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.rating = 0,
    this.ratingCount = 0,
    this.products = const [],
  });

  static double? _numOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static double _num(dynamic v, [double fallback = 0]) => _numOrNull(v) ?? fallback;

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        id:         json['id'] as String,
        name:       json['name'] as String,
        phone:      json['phone'] as String?,
        address:    json['address'] as String?,
        latitude:   _numOrNull(json['latitude']),
        longitude:  _numOrNull(json['longitude']),
        // BUG CORRIGÉ : distance_km vient d'une expression SQL brute
        // (formule haversine) — PostgreSQL/PHP la renvoie en chaîne de
        // texte ("0.0021...") et non en nombre JSON natif. Le cast
        // `as num?` plantait alors systématiquement (String n'est pas un
        // num), faisant échouer TOUTE la recherche même quand le serveur
        // renvoyait des données parfaitement valides.
        distanceKm: _numOrNull(json['distance_km']),
        rating:     _num(json['rating']),
        ratingCount:(json['rating_count'] as num?)?.toInt() ?? int.tryParse(json['rating_count']?.toString() ?? '') ?? 0,
        products:   (json['products'] as List<dynamic>? ?? [])
            .map((p) => StoreProductModel.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

class PartOrderItemModel {
  final String productName;
  final double unitPrice;
  final int quantity;
  final double subtotal;

  const PartOrderItemModel({
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
  });

  factory PartOrderItemModel.fromJson(Map<String, dynamic> json) => PartOrderItemModel(
        productName: json['product_name'] as String,
        unitPrice:   (json['unit_price'] as num?)?.toDouble() ?? 0,
        quantity:    (json['quantity'] as num?)?.toInt() ?? 0,
        subtotal:    (json['subtotal'] as num?)?.toDouble() ?? 0,
      );
}

class PartOrderModel {
  final String id;
  final String status;
  final double totalAmount;
  final DateTime createdAt;
  final List<PartOrderItemModel> items;
  final Map<String, dynamic>? store;

  const PartOrderModel({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    this.items = const [],
    this.store,
  });

  factory PartOrderModel.fromJson(Map<String, dynamic> json) => PartOrderModel(
        id:          json['id'] as String,
        status:      json['status'] as String? ?? 'pending',
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        createdAt:   DateTime.parse(json['created_at'] as String),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((i) => PartOrderItemModel.fromJson(i as Map<String, dynamic>))
            .toList(),
        store: json['store'] as Map<String, dynamic>?,
      );
}
