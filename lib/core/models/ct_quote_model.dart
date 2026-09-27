// lib/core/models/ct_quote_model.dart
// ignore_for_file: invalid_annotation_target

class CtQuoteRequestModel {
  final String id;
  final String vehicleId;
  final String? providerId;
  final String transportMode;
  final String? notes;
  final String status; // pending | quoted | accepted | refused | expired | booked
  final DateTime createdAt;
  final CtQuoteModel? quote;

  const CtQuoteRequestModel({
    required this.id,
    required this.vehicleId,
    this.providerId,
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
      providerId: json['provider_id'] as String?,
      transportMode: json['transport_mode'] as String? ?? 'self',
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      quote: json['quote'] != null
          ? CtQuoteModel.fromJson(json['quote'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isPending  => status == 'pending';
  bool get isQuoted   => status == 'quoted';
  bool get isAccepted => status == 'accepted';
  bool get isRefused  => status == 'refused';
  bool get isBooked   => status == 'booked';
}

/// Devis CT envoyé par l'admin.
/// Les champs *_amount représentent le détail des frais :
///   - partner_amount     : frais partenaire CT
///   - option_amount      : frais option selon transport_mode
///   - digital_fee_amount : frais service VigiRoutes
///   - base_amount        : montant brut avant ajustement (optionnel)
///   - final_amount       : total final = ce que voit le client en grand
class CtQuoteModel {
  final String id;
  final int baseAmount;
  final int finalAmount;

  // Détail des frais (remplis par le backend si disponibles)
  final int? partnerAmount;
  final int? optionAmount;
  final int? digitalFeeAmount;

  final String? adminNotes;
  final String status; // sent | accepted | refused | expired
  final DateTime? validUntil;
  final DateTime? respondedAt;
  final List<CtQuoteOperatorModel> operators;

  const CtQuoteModel({
    required this.id,
    required this.baseAmount,
    required this.finalAmount,
    this.partnerAmount,
    this.optionAmount,
    this.digitalFeeAmount,
    this.adminNotes,
    required this.status,
    this.validUntil,
    this.respondedAt,
    this.operators = const [],
  });

  factory CtQuoteModel.fromJson(Map<String, dynamic> json) {
    return CtQuoteModel(
      id:          json['id'] as String,
      baseAmount:  _toInt(json['base_amount']),
      finalAmount: _toInt(json['final_amount']),
      partnerAmount:    json['partner_amount']    != null ? _toInt(json['partner_amount'])    : null,
      optionAmount:     json['option_amount']     != null ? _toInt(json['option_amount'])     : null,
      digitalFeeAmount: json['digital_fee_amount'] != null ? _toInt(json['digital_fee_amount']) : null,
      adminNotes:  json['admin_notes'] as String?,
      status:      json['status'] as String? ?? 'sent',
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

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  bool get isExpired  => validUntil != null && DateTime.now().isAfter(validUntil!);
  bool get canRespond => status == 'sent' && !isExpired;

  /// true si le backend a renvoyé le détail des frais
  bool get hasBreakdown =>
      partnerAmount != null && optionAmount != null && digitalFeeAmount != null;
}

class CtQuoteOperatorModel {
  final String operatorId;
  final String? operatorName;

  const CtQuoteOperatorModel({required this.operatorId, this.operatorName});

  factory CtQuoteOperatorModel.fromJson(Map<String, dynamic> json) {
    return CtQuoteOperatorModel(
      operatorId:   json['operator_id']   as String,
      operatorName: json['operator_name'] as String?,
    );
  }
}

class CtBookingHint {
  final String vehicleId;
  final String quoteId;
  final List<String> operatorIds;
  final int amount;
  final String transportMode;

  const CtBookingHint({
    required this.vehicleId,
    required this.quoteId,
    required this.operatorIds,
    required this.amount,
    this.transportMode = 'self',
  });

  factory CtBookingHint.fromJson(Map<String, dynamic> json) {
    return CtBookingHint(
      vehicleId:     json['vehicle_id'] as String,
      quoteId:       json['quote_id']   as String,
      operatorIds:   (json['operator_ids'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      amount:        _toInt(json['amount']),
      transportMode: json['transport_mode'] as String? ?? 'self',
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
