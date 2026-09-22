// ignore_for_file: invalid_annotation_target

class CtQuoteRequestModel {
  final String id;
  final String vehicleId;
  final String transportMode;
  final String? notes;
  final String status; // pending | quoted | accepted | refused | expired | booked
  final DateTime createdAt;
  final CtQuoteModel? quote;

  const CtQuoteRequestModel({
    required this.id,
    required this.vehicleId,
    required this.transportMode,
    this.notes,
    required this.status,
    required this.createdAt,
    this.quote,
  });

  factory CtQuoteRequestModel.fromJson(Map<String, dynamic> json) {
    return CtQuoteRequestModel(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String? ?? '',
      transportMode: json['transport_mode'] as String? ?? 'self',
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      quote: json['quote'] != null
          ? CtQuoteModel.fromJson(json['quote'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isQuoted => status == 'quoted';
  bool get isAccepted => status == 'accepted';
  bool get isRefused => status == 'refused';
  bool get isBooked => status == 'booked';
}

class CtQuoteModel {
  final String id;
  final int baseAmount;
  final int finalAmount;
  final String? adminNotes;
  final String status; // sent | accepted | refused | expired
  final DateTime? validUntil;
  final DateTime? respondedAt;
  final List<CtQuoteOperatorModel> operators;

  const CtQuoteModel({
    required this.id,
    required this.baseAmount,
    required this.finalAmount,
    this.adminNotes,
    required this.status,
    this.validUntil,
    this.respondedAt,
    this.operators = const [],
  });

  factory CtQuoteModel.fromJson(Map<String, dynamic> json) {
    return CtQuoteModel(
      id: json['id'] as String,
      baseAmount: json['base_amount'] as int? ?? 0,
      finalAmount: json['final_amount'] as int? ?? 0,
      adminNotes: json['admin_notes'] as String?,
      status: json['status'] as String? ?? 'sent',
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'] as String)
          : null,
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
      operators: (json['operators'] as List<dynamic>? ?? [])
          .map((e) => CtQuoteOperatorModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isExpired => validUntil != null && DateTime.now().isAfter(validUntil!);
  bool get canRespond => status == 'sent' && !isExpired;
}

class CtQuoteOperatorModel {
  final int operatorId;
  final String? operatorName;

  const CtQuoteOperatorModel({required this.operatorId, this.operatorName});

  factory CtQuoteOperatorModel.fromJson(Map<String, dynamic> json) {
    return CtQuoteOperatorModel(
      operatorId: json['operator_id'] as int,
      operatorName: json['operator_name'] as String?,
    );
  }
}

class CtBookingHint {
  final String vehicleId;
  final String quoteId;
  final List<int> operatorIds;
  final int amount;

  const CtBookingHint({
    required this.vehicleId,
    required this.quoteId,
    required this.operatorIds,
    required this.amount,
  });

  factory CtBookingHint.fromJson(Map<String, dynamic> json) {
    return CtBookingHint(
      vehicleId: json['vehicle_id'] as String,
      quoteId: json['quote_id'] as String,
      operatorIds: (json['operator_ids'] as List<dynamic>).map((e) => e as int).toList(),
      amount: json['amount'] as int,
    );
  }
}
