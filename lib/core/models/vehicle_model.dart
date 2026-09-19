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
  final String? energy;
  final String? chassisNumber;

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

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        registrationNumber: json['registration_number'] as String,
        brand: json['brand'] as String,
        model: json['model'] as String,
        color: json['color'] as String?,
        year: json['year'] as int?,
        category: json['category'] as String? ?? 'VP',
        energy: json['energy'] as String?,
        chassisNumber: json['chassis_number'] as String?,
        technicalVisitExpiresAt: json['technical_visit_expires_at'] != null
            ? DateTime.parse(json['technical_visit_expires_at'] as String)
            : null,
        tvDateVerified: json['tv_date_verified'] as bool? ?? false,
        insuranceExpiresAt: json['insurance_expires_at'] != null
            ? DateTime.parse(json['insurance_expires_at'] as String)
            : null,
        insuranceDateVerified: json['insurance_date_verified'] as bool? ?? false,
        vignetteExpiresAt: json['vignette_expires_at'] != null
            ? DateTime.parse(json['vignette_expires_at'] as String)
            : null,
        photoUrl: json['photo_url'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'registration_number': registrationNumber,
        'brand': brand,
        'model': model,
        'color': color,
        'year': year,
        'category': category,
        'energy': energy,
        'chassis_number': chassisNumber,
        'technical_visit_expires_at': technicalVisitExpiresAt?.toIso8601String().split('T').first,
        'insurance_expires_at': insuranceExpiresAt?.toIso8601String().split('T').first,
        'vignette_expires_at': vignetteExpiresAt?.toIso8601String().split('T').first,
        'is_primary': isPrimary,
      };

  VehicleModel copyWith({
    String? brand, String? model, String? color, int? year,
    String? category, String? energy, DateTime? technicalVisitExpiresAt,
    DateTime? insuranceExpiresAt, DateTime? vignetteExpiresAt, String? photoUrl,
    bool? isPrimary,
  }) => VehicleModel(
        id: id, userId: userId, registrationNumber: registrationNumber,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        color: color ?? this.color,
        year: year ?? this.year,
        category: category ?? this.category,
        energy: energy ?? this.energy,
        technicalVisitExpiresAt: technicalVisitExpiresAt ?? this.technicalVisitExpiresAt,
        tvDateVerified: tvDateVerified,
        insuranceExpiresAt: insuranceExpiresAt ?? this.insuranceExpiresAt,
        insuranceDateVerified: insuranceDateVerified,
        vignetteExpiresAt: vignetteExpiresAt ?? this.vignetteExpiresAt,
        photoUrl: photoUrl ?? this.photoUrl,
        isPrimary: isPrimary ?? this.isPrimary,
        createdAt: createdAt,
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

  double get displayLatitude => sessionLatitude ?? latitude ?? 5.345317;
  double get displayLongitude => sessionLongitude ?? longitude ?? -4.024429;

  factory TechnicalCenterModel.fromJson(Map<String, dynamic> json) => TechnicalCenterModel(
        id: json['id'] as String,
        operatorId: json['operator_id'] as String,
        operatorName: json['operator']?['name'] as String? ?? '',
        name: json['name'] as String,
        type: json['type'] as String? ?? 'fixed',
        latitude: _toDoubleOrNull(json['latitude']),
        longitude: _toDoubleOrNull(json['longitude']),
        address: json['address'] as String?,
        city: json['city'] as String? ?? 'Abidjan',
        contactPhone: json['contact_phone'] as String?,
        openingTime: json['opening_time'] as String? ?? '07:00',
        closingTime: json['closing_time'] as String? ?? '17:00',
        dailyCapacity: json['daily_capacity'] as int? ?? 20,
        isActive: json['is_active'] as bool? ?? true,
        photoUrl: json['photo_url'] as String?,
        description: json['description'] as String?,
        acceptedVehicleCategories: (json['accepted_vehicle_categories'] as List<dynamic>?)
                ?.cast<String>() ??
            ['VP', 'VU', 'Moto'],
        sessionLatitude: _toDoubleOrNull(json['session_latitude']),
        sessionLongitude: _toDoubleOrNull(json['session_longitude']),
        sessionAddress: json['session_address'] as String?,
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

  factory SessionSlotModel.fromJson(Map<String, dynamic> json) => SessionSlotModel(
        sessionId: json['session_id'] as String,
        slotTime: json['slot_time'] as String,
        remainingSlots: json['remaining_slots'] as int? ?? 0,
        isAvailable: json['is_available'] as bool? ?? false,
      );
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

  bool get hasQr => qrToken != null && qrExpiresAt != null && qrExpiresAt!.isAfter(DateTime.now());

  factory CtBookingModel.fromJson(Map<String, dynamic> json) => CtBookingModel(
        id: json['id'] as String,
        reference: json['reference'] as String,
        vehicle: VehicleModel.fromJson(json['vehicle'] as Map<String, dynamic>),
        center: TechnicalCenterModel.fromJson(json['center'] as Map<String, dynamic>),
        slotStartsAt: DateTime.parse(json['slot_starts_at'] as String),
        slotReservedUntil: json['slot_reserved_until'] != null
            ? DateTime.parse(json['slot_reserved_until'] as String)
            : null,
        transportMode: json['transport_mode'] as String? ?? 'self',
        keyHandoverAccepted: json['key_handover_accepted'] as bool? ?? false,
        bookingFee: _toDouble(json['booking_fee']),
        transportFee: _toDouble(json['transport_fee']),
        totalAmount: _toDouble(json['total_amount']),
        paymentStatus: json['payment_status'] as String? ?? 'pending',
        paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
        qrToken: json['qr_token'] as String?,
        qrExpiresAt: json['qr_expires_at'] != null
            ? DateTime.parse(json['qr_expires_at'] as String)
            : null,
        status: json['status'] as String,
        vtResult: json['vt_result'] as String?,
        vtReportNotes: json['vt_report_notes'] as String?,
        vtCompletedAt: json['vt_completed_at'] != null
            ? DateTime.parse(json['vt_completed_at'] as String)
            : null,
        nextVtDueDate: json['next_vt_due_date'] != null
            ? DateTime.parse(json['next_vt_due_date'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// Helpers
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
