// lib/core/models/ct_quote_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Modèles du module Devis CT.
//
// ⚠️ CONTRAT BACKEND (validé le 28/09/2026) :
//   - GET  /api/client/ct/quote-requests       → {data: [CtQuoteRequestModel]}
//   - GET  /api/client/ct/quote-requests/{id}  → {data: CtQuoteRequestModel}
//   - POST /api/client/ct/quote-requests       → {data: CtQuoteRequestModel}
//   - POST /api/client/ct/quote-requests/{id}/respond → {message, booking_hint?}
//
// Le format `quote` renvoyé par le backend contient maintenant le détail
// des frais : partner_amount, option_amount, digital_fee_amount.
// ─────────────────────────────────────────────────────────────────────────────

/// Conversions tolérantes : l'API peut renvoyer int, double ou String
/// selon le driver SQL (PostgreSQL renvoie souvent numeric en String).
int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

// ─────────────────────────────────────────────────────────────────────────────
// CtQuoteRequestModel — une demande de devis (côté client)
// ─────────────────────────────────────────────────────────────────────────────

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
    final vehicleJson = json['vehicle'] as Map<String, dynamic>?;

    return CtQuoteRequestModel(
      id:            json['id'] as String,
      vehicleId:     vehicleJson?['id'] as String? ?? '',
      providerId:    json['provider_id'] as String?,
      transportMode: json['transport_mode'] as String? ?? 'self',
      notes:         json['notes'] as String?,
      status:        json['status'] as String? ?? 'pending',
      createdAt:     _toDate(json['created_at']) ?? DateTime.now(),
      quote: json['quote'] != null
          ? CtQuoteModel.fromJson(json['quote'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isPending  => status == 'pending';
  bool get isQuoted   => status == 'quoted';
  bool get isAccepted => status == 'accepted';
  bool get isRefused  => status == 'refused';
  bool get isExpired  => status == 'expired';
  bool get isBooked   => status == 'booked';

  bool get canRespond => quote?.canRespond ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────
// CtQuoteModel — le devis émis par l'admin
// ─────────────────────────────────────────────────────────────────────────────

/// Devis CT envoyé par l'admin.
///
/// Détail des frais (rempli par l'admin lors de l'envoi) :
///   - partnerAmount     : frais partenaire CT
///   - optionAmount      : frais option selon transport_mode
///   - digitalFeeAmount  : frais de service VigiRoutes
///   - baseAmount        : montant brut avant ajustement (legacy)
///   - finalAmount       : total final affiché en grand
class CtQuoteModel {
  final String id;
  final int baseAmount;
  final int finalAmount;

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
      partnerAmount:    _toIntOrNull(json['partner_amount']),
      optionAmount:     _toIntOrNull(json['option_amount']),
      digitalFeeAmount: _toIntOrNull(json['digital_fee_amount']),
      adminNotes:  json['admin_notes'] as String?,
      status:      json['status'] as String? ?? 'sent',
      validUntil:  _toDate(json['valid_until']),
      respondedAt: _toDate(json['responded_at']),
      operators: (json['operators'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CtQuoteOperatorModel.fromJson)
          .toList(),
    );
  }

  bool get isSent     => status == 'sent';
  bool get isAccepted => status == 'accepted';
  bool get isRefused  => status == 'refused';
  bool get isExpiredStatus => status == 'expired';

  bool get isExpired =>
      validUntil != null && DateTime.now().isAfter(validUntil!);

  bool get canRespond => isSent && !isExpired;

  bool get hasBreakdown =>
      partnerAmount != null &&
      optionAmount != null &&
      digitalFeeAmount != null;

  int? get sumOfBreakdown => hasBreakdown
      ? (partnerAmount! + optionAmount! + digitalFeeAmount!)
      : null;

  int? get breakdownDelta => hasBreakdown ? (finalAmount - sumOfBreakdown!) : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// CtQuoteOperatorModel — opérateur CT proposé dans un devis
// ─────────────────────────────────────────────────────────────────────────────

class CtQuoteOperatorModel {
  final String operatorId;
  final String? operatorName;

  const CtQuoteOperatorModel({
    required this.operatorId,
    this.operatorName,
  });

  factory CtQuoteOperatorModel.fromJson(Map<String, dynamic> json) {
    return CtQuoteOperatorModel(
      operatorId:   json['operator_id'] as String,
      operatorName: json['operator_name'] as String?,
    );
  }

  String get displayName =>
      (operatorName != null && operatorName!.trim().isNotEmpty)
          ? operatorName!.trim()
          : 'Opérateur #$operatorId';
}

// ─────────────────────────────────────────────────────────────────────────────
// CtBookingHint — passé du détail devis vers le flow de réservation
// ─────────────────────────────────────────────────────────────────────────────

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
      vehicleId: json['vehicle_id'] as String,
      quoteId:   json['quote_id']   as String,
      operatorIds: (json['operator_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      amount:        _toInt(json['amount']),
      transportMode: json['transport_mode'] as String? ?? 'self',
    );
  }

  bool get hasOperators => operatorIds.isNotEmpty;
  bool get isTransportLocked => transportMode != 'self';
}