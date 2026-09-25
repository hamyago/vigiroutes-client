// models/vehicle_model.dart
// Fiche numérique d'un véhicule — Module CT VigiRoutes Client

class VehicleModel {
  final String id;
  final String userId;
  final String registrationNumber;
  final String brand;
  final String model;
  final String? color;
  final int? year;
  final String category; // VP, VU, Moto, Camion
  final String? energy;  // gasoil | essence | hybride | electrique
  final String? chassisNumber;
  final String? carteGriseNumber;  // Numéro carte grise
  final int?    puissanceCv;       // Puissance fiscale en CV
  final int?    placesAssises;     // Nombre de places assises
  final String? usage;             // public | privée

  // Dates expiration
  final DateTime? technicalVisitExpiresAt;
  final bool tvDateVerified;
  final DateTime? insuranceExpiresAt;
  final bool insuranceDateVerified;
  final DateTime? vignetteExpiresAt;

  final String? photoUrl;
  final bool isPrimary;
  final DateTime createdAt;

  const VehicleModel({
    required this.id,
    required this.userId,
    required this.registrationNumber,
    required this.brand,
    required this.model,
    this.color,
    this.year,
    required this.category,
    this.energy,
    this.chassisNumber,
    this.carteGriseNumber,
    this.puissanceCv,
    this.placesAssises,
    this.usage,
    this.technicalVisitExpiresAt,
    this.tvDateVerified = false,
    this.insuranceExpiresAt,
    this.insuranceDateVerified = false,
    this.vignetteExpiresAt,
    this.photoUrl,
    this.isPrimary = false,
    required this.createdAt,
  });

  /// Nombre de jours avant expiration VT. Négatif si déjà expirée.
  int? get daysUntilVtExpiry {
    if (technicalVisitExpiresAt == null) return null;
    return technicalVisitExpiresAt!.difference(DateTime.now()).inDays;
  }

  /// Niveau d'alerte VT
  VtAlertLevel get vtAlertLevel {
    final days = daysUntilVtExpiry;
    if (days == null) return VtAlertLevel.none;
    if (days < 0) return VtAlertLevel.expired;
    if (days <= 7) return VtAlertLevel.critical;
    if (days <= 15) return VtAlertLevel.warning;
    if (days <= 30) return VtAlertLevel.info;
    return VtAlertLevel.ok;
  }

  static String _str(dynamic v, [String fallback = '']) =>
      v == null ? fallback : v.toString();

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
        id:                     _str(json['id']),
        userId:                 _str(json['user_id']),
        registrationNumber:     _str(json['registration_number']),
        brand:                  _str(json['brand']),
        model:                  _str(json['model']),
        color:                  json['color']?.toString(),
        year:                   _intOrNull(json['year']),
        category:               _str(json['category'], 'VP'),
        energy:                 json['energy']?.toString(),
        chassisNumber:          json['chassis_number']?.toString(),
        carteGriseNumber:       json['carte_grise_number']?.toString(),
        puissanceCv:            _intOrNull(json['puissance_cv']),
        placesAssises:          _intOrNull(json['places_assises']),
        usage:                  json['usage']?.toString(),
        technicalVisitExpiresAt: json['technical_visit_expires_at'] != null
            ? DateTime.tryParse(json['technical_visit_expires_at'].toString())
            : null,
        tvDateVerified:          json['tv_date_verified'] == true || json['tv_date_verified'] == 1,
        insuranceExpiresAt: json['insurance_expires_at'] != null
            ? DateTime.tryParse(json['insurance_expires_at'].toString())
            : null,
        insuranceDateVerified: json['insurance_date_verified'] == true || json['insurance_date_verified'] == 1,
        vignetteExpiresAt: json['vignette_expires_at'] != null
            ? DateTime.tryParse(json['vignette_expires_at'].toString())
            : null,
        photoUrl:  json['photo_url']?.toString(),
        isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'registration_number':  registrationNumber,
        'brand':                brand,
        'model':                model,
        'color':                color,
        'year':                 year,
        'category':             category,
        'energy':               energy,
        'chassis_number':       chassisNumber,
        'carte_grise_number':   carteGriseNumber,
        'puissance_cv':         puissanceCv,
        'places_assises':       placesAssises,
        'usage':                usage,
        'technical_visit_expires_at': technicalVisitExpiresAt?.toIso8601String().split('T').first,
        'insurance_expires_at': insuranceExpiresAt?.toIso8601String().split('T').first,
        'vignette_expires_at':  vignetteExpiresAt?.toIso8601String().split('T').first,
        'is_primary':           isPrimary,
      };

  VehicleModel copyWith({
    String? brand,
    String? model,
    String? color,
    int?    year,
    String? category,
    String? energy,
    String? chassisNumber,
    String? carteGriseNumber,
    int?    puissanceCv,
    int?    placesAssises,
    String? usage,
    DateTime? technicalVisitExpiresAt,
    DateTime? insuranceExpiresAt,
    DateTime? vignetteExpiresAt,
    String? photoUrl,
    bool?   isPrimary,
  }) => VehicleModel(
        id:                    id,
        userId:                userId,
        registrationNumber:    registrationNumber,
        brand:                 brand  ?? this.brand,
        model:                 model  ?? this.model,
        color:                 color  ?? this.color,
        year:                  year   ?? this.year,
        category:              category ?? this.category,
        energy:                energy ?? this.energy,
        chassisNumber:         chassisNumber ?? this.chassisNumber,
        carteGriseNumber:      carteGriseNumber ?? this.carteGriseNumber,
        puissanceCv:           puissanceCv ?? this.puissanceCv,
        placesAssises:         placesAssises ?? this.placesAssises,
        usage:                 usage ?? this.usage,
        technicalVisitExpiresAt: technicalVisitExpiresAt ?? this.technicalVisitExpiresAt,
        tvDateVerified:        tvDateVerified,
        insuranceExpiresAt:    insuranceExpiresAt ?? this.insuranceExpiresAt,
        insuranceDateVerified: insuranceDateVerified,
        vignetteExpiresAt:     vignetteExpiresAt ?? this.vignetteExpiresAt,
        photoUrl:              photoUrl ?? this.photoUrl,
        isPrimary:             isPrimary ?? this.isPrimary,
        createdAt:             createdAt,
      );
}

enum VtAlertLevel { none, ok, info, warning, critical, expired }

// ── TechnicalCenterModel ──────────────────────────────────────────────────────

class TechnicalCenterModel {
  final String id;
  final String operatorId;
  final String operatorName;
  final String name;
  final String type; // fixed | mobile
  final double? latitude;
  final double? longitude;
  final String? address;
  final String city;
  final String? contactPhone;
  final String openingTime;
  final String closingTime;
  final int dailyCapacity;
  final bool isActive;
  final String? photoUrl;
  final String? description;
  final List<String> acceptedVehicleCategories;

  // GPS actuel (pour unité mobile : peut différer de la position fixe)
  final double? sessionLatitude;
  final double? sessionLongitude;
  final String? sessionAddress;

  // Slots disponibles pour la date demandée
  final List<SessionSlotModel> availableSlots;

  const TechnicalCenterModel({
    required this.id,
    required this.operatorId,
    required this.operatorName,
    required this.name,
    required this.type,
    this.latitude,
    this.longitude,
    this.address,
    required this.city,
    this.contactPhone,
    required this.openingTime,
    required this.closingTime,
    required this.dailyCapacity,
    required this.isActive,
    this.photoUrl,
    this.description,
    this.acceptedVehicleCategories = const ['VP', 'VU', 'Moto'],
    this.sessionLatitude,
    this.sessionLongitude,
    this.sessionAddress,
    this.availableSlots = const [],
  });

  bool get isMobile => type == 'mobile';

  double get displayLatitude  => sessionLatitude  ?? latitude  ?? 5.345317;
  double get displayLongitude => sessionLongitude ?? longitude ?? -4.024429;

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory TechnicalCenterModel.fromJson(Map<String, dynamic> json) => TechnicalCenterModel(
        id:           (json['id'] ?? '').toString(),
        // L'API retourne operator_id en plat OU dans l'objet operator
        operatorId:   (json['operator_id'] ?? json['operator']?['id'] ?? '').toString(),
        // L'API retourne operator_name en plat OU dans l'objet operator
        operatorName: (json['operator_name'] ?? json['operator']?['name'] ?? '').toString(),
        name:         (json['name'] ?? '').toString(),
        type:         (json['type'] ?? 'fixed').toString(),
        latitude:     _dbl(json['latitude']),
        longitude:    _dbl(json['longitude']),
        address:      json['address']?.toString(),
        city:         (json['city'] ?? 'Abidjan').toString(),
        contactPhone: json['contact_phone']?.toString(),
        openingTime:  (json['opening_time'] ?? '07:00').toString(),
        closingTime:  (json['closing_time'] ?? '17:00').toString(),
        dailyCapacity: json['daily_capacity'] is int ? json['daily_capacity'] : 20,
        isActive:     json['is_active'] == true || json['is_active'] == 1,
        photoUrl:     json['photo_url']?.toString(),
        description:  json['description']?.toString(),
        acceptedVehicleCategories:
            (json['accepted_vehicle_categories'] as List<dynamic>?)?.cast<String>() ??
            ['VP', 'VU', 'Moto'],
        sessionLatitude:  _dbl(json['session_latitude']),
        sessionLongitude: _dbl(json['session_longitude']),
        sessionAddress:   json['session_address']?.toString(),
        availableSlots: (json['available_slots'] as List<dynamic>?)
                ?.map((s) => SessionSlotModel.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class SessionSlotModel {
  final String sessionId;
  final String slotTime;       // "08:00"
  final int remainingSlots;
  final bool isAvailable;

  const SessionSlotModel({
    required this.sessionId,
    required this.slotTime,
    required this.remainingSlots,
    required this.isAvailable,
  });

  factory SessionSlotModel.fromJson(Map<String, dynamic> json) {
    final remaining = json['remaining_slots'] is int
        ? json['remaining_slots'] as int
        : int.tryParse(json['remaining_slots']?.toString() ?? '0') ?? 0;
    // L'API renvoie remaining_slots (int), pas is_available (bool)
    final available = json['is_available'] != null
        ? (json['is_available'] == true || json['is_available'] == 1)
        : remaining > 0;
    return SessionSlotModel(
      sessionId:      (json['session_id'] ?? '').toString(),
      slotTime:       (json['slot_time'] ?? '').toString(),
      remainingSlots: remaining,
      isAvailable:    available,
    );
  }
}

// ── CtBookingModel ────────────────────────────────────────────────────────────

class CtBookingModel {
  final String id;
  final String reference;
  final VehicleModel vehicle;
  final TechnicalCenterModel center;
  final DateTime slotStartsAt;
  final DateTime? slotReservedUntil;
  final String transportMode;
  final bool keyHandoverAccepted;
  final double bookingFee;
  final double transportFee;
  final double totalAmount;
  final String paymentStatus;
  final String? paymentMethod;
  final DateTime? paidAt;
  final String? qrToken;
  final DateTime? qrExpiresAt;
  final String status;
  final String? vtResult;
  final String? vtReportNotes;
  final DateTime? vtCompletedAt;
  final DateTime? nextVtDueDate;
  final DateTime createdAt;

  const CtBookingModel({
    required this.id,
    required this.reference,
    required this.vehicle,
    required this.center,
    required this.slotStartsAt,
    this.slotReservedUntil,
    required this.transportMode,
    this.keyHandoverAccepted = false,
    required this.bookingFee,
    required this.transportFee,
    required this.totalAmount,
    required this.paymentStatus,
    this.paymentMethod,
    this.paidAt,
    this.qrToken,
    this.qrExpiresAt,
    required this.status,
    this.vtResult,
    this.vtReportNotes,
    this.vtCompletedAt,
    this.nextVtDueDate,
    required this.createdAt,
  });

  bool get hasQr =>
      qrToken != null &&
      qrExpiresAt != null &&
      qrExpiresAt!.isAfter(DateTime.now());

  static double _dbl(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  // FIX CRITIQUE : le backend (formatBooking) retourne les champs à plat :
  //   vehicle_brand, vehicle_model, registration_number, vehicle_color,
  //   vehicle_category, center_id, center_name, center_address,
  //   session_date, slot_starts_at.
  // On accepte les DEUX formats : objet imbriqué (vehicle{}, center{})
  // ET colonnes à plat — pour rester compatible quelle que soit l'évolution
  // de l'API.
  factory CtBookingModel.fromJson(Map<String, dynamic> json) {
    // ── Véhicule ──────────────────────────────────────────────────────────
    final VehicleModel vehicle;
    if (json['vehicle'] is Map) {
      // Format imbriqué : {"vehicle": {"id": ..., "brand": ...}}
      vehicle = VehicleModel.fromJson(json['vehicle'] as Map<String, dynamic>);
    } else {
      // Format plat renvoyé par formatBooking/bookingSelectColumns
      vehicle = VehicleModel(
        id:                 (json['vehicle_id'] ?? json['id'] ?? '').toString(),
        userId:             '',
        registrationNumber: (json['registration_number'] ?? '').toString(),
        brand:              (json['vehicle_brand'] ?? '').toString(),
        model:              (json['vehicle_model'] ?? '').toString(),
        color:              json['vehicle_color']?.toString(),
        category:           (json['vehicle_category'] ?? 'VP').toString(),
        createdAt:          DateTime.now(),
      );
    }

    // ── Centre ────────────────────────────────────────────────────────────
    final TechnicalCenterModel center;
    if (json['center'] is Map) {
      // Format imbriqué : {"center": {"id": ..., "name": ...}}
      center = TechnicalCenterModel.fromJson(json['center'] as Map<String, dynamic>);
    } else {
      // Format plat renvoyé par formatBooking/bookingSelectColumns
      center = TechnicalCenterModel(
        id:           (json['center_id'] ?? '').toString(),
        operatorId:   '',
        operatorName: '',
        name:         (json['center_name'] ?? '').toString(),
        type:         'fixed',
        address:      json['center_address']?.toString(),
        city:         (json['center_city'] ?? 'Abidjan').toString(),
        openingTime:  '07:00',
        closingTime:  '17:00',
        dailyCapacity: 20,
        isActive:     true,
      );
    }

    // ── Date du créneau ───────────────────────────────────────────────────
    // Le backend peut renvoyer slot_starts_at (datetime) ou
    // session_date + slot_starts_at (time séparé).
    DateTime slotStartsAt = DateTime.now();
    if (json['slot_starts_at'] != null) {
      slotStartsAt = _dt(json['slot_starts_at']) ?? DateTime.now();
    } else if (json['session_date'] != null) {
      // Reconstituer depuis session_date "2025-03-15" + start_time "08:00"
      final datePart = json['session_date'].toString();
      final timePart = (json['start_time'] ?? json['slot_time'] ?? '00:00').toString();
      slotStartsAt = _dt('${datePart}T$timePart:00') ?? DateTime.now();
    }

    return CtBookingModel(
      id:                  (json['id'] ?? '').toString(),
      reference:           (json['reference'] ?? '').toString(),
      vehicle:             vehicle,
      center:              center,
      slotStartsAt:        slotStartsAt,
      slotReservedUntil:   _dt(json['slot_reserved_until']),
      transportMode:       (json['transport_mode'] ?? 'self').toString(),
      keyHandoverAccepted: json['key_handover_accepted'] == true || json['key_handover_accepted'] == 1,
      bookingFee:          _dbl(json['booking_fee']),
      transportFee:        _dbl(json['transport_fee']),
      totalAmount:         _dbl(json['total_amount']),
      paymentStatus:       (json['payment_status'] ?? 'pending').toString(),
      paymentMethod:       json['payment_method']?.toString(),
      paidAt:              _dt(json['paid_at']),
      qrToken:             json['qr_token']?.toString(),
      qrExpiresAt:         _dt(json['qr_expires_at']),
      status:              (json['status'] ?? 'pending').toString(),
      vtResult:            json['vt_result']?.toString(),
      vtReportNotes:       json['vt_report_notes']?.toString(),
      vtCompletedAt:       _dt(json['vt_completed_at']),
      nextVtDueDate:       _dt(json['next_vt_due_date']),
      createdAt:           _dt(json['created_at']) ?? DateTime.now(),
    );
  }
}
