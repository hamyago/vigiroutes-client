// lib/core/services/ct_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Service du module CT (véhicules, centres, créneaux, réservations).
//
// ⚠️ CONTRAT BACKEND (validé le 28/09/2026) :
//   - GET    /ct/vehicles                → {data: [VehicleModel]}
//   - POST   /ct/vehicles                → {data: VehicleModel}   (201)
//   - PATCH  /ct/vehicles/{id}           → {data: VehicleModel}
//   - DELETE /ct/vehicles/{id}           → {message: "..."}
//   - GET    /ct/centers?date=...        → {data: [TechnicalCenterModel]}
//   - GET    /ct/centers/{id}/slots?date → {data: [SessionSlotModel]}
//   - GET    /ct/bookings                → {data: [CtBookingModel]}
//   - POST   /ct/bookings                → {data: CtBookingModel}   (201)
//   - GET    /ct/bookings/{id}           → {data: CtBookingModel}
//   - POST   /ct/bookings/{id}/cancel    → {message: "..."}
//   - POST   /ct/bookings/{id}/pay       → {message, qr_token?, payment_url?}
//   - GET    /ct/bookings/{id}/qr        → {data: {qr_token: "..."}}
//
// Le filtre `operator_ids[]` sur /ct/centers est maintenant pris en compte
// par le backend (voir CtController::centersIndex()).
// ─────────────────────────────────────────────────────────────────────────────

import 'api_service.dart';
import '../models/vehicle_model.dart';

class CtService {
  CtService._();
  static final CtService instance = CtService._();

  final _api = ApiService.instance;

  static const _base = 'https://api.vigiroutes.com/api';

  // ── Helpers internes ─────────────────────────────────────────────────────

  /// Extrait une liste depuis une réponse JSON Laravel.
  /// Tolère les formats {data: [...]}, {vehicles: [...]}, [...].
  List<dynamic> _extractList(dynamic raw, {String? key}) {
    if (raw is List) return raw;
    if (raw is Map) {
      if (key != null && raw[key] is List) return raw[key] as List;
      if (raw['data'] is List) return raw['data'] as List;
      if (raw['vehicles'] is List) return raw['vehicles'] as List;
    }
    return const [];
  }

  /// Extrait un objet depuis une réponse JSON Laravel.
  /// Tolère les formats {data: {...}} et {...}.
  Map<String, dynamic> _extractObject(dynamic raw, {String? key}) {
    if (raw is Map<String, dynamic>) {
      if (key != null && raw[key] is Map) {
        return Map<String, dynamic>.from(raw[key] as Map);
      }
      if (raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    throw FormatException(
      'Réponse API inattendue : ${raw.runtimeType}',
      raw is Object ? raw.toString() : null,
    );
  }

  // ── Véhicules ──────────────────────────────────────────────────────────

  /// GET /ct/vehicles
  /// Retourne tous les véhicules du client connecté.
  Future<List<VehicleModel>> getVehicles() async {
    final res = await _api.get('/ct/vehicles');
    final list = _extractList(res.data, key: 'data');
    return list
        .whereType<Map<String, dynamic>>()
        .map(VehicleModel.fromJson)
        .toList();
  }

  /// POST /ct/vehicles
  /// Crée un nouveau véhicule (fiche CT complète).
  Future<VehicleModel> createVehicle(Map<String, dynamic> data) async {
    final res = await _api.post('/ct/vehicles', data: data);
    final obj = _extractObject(res.data, key: 'data');
    return VehicleModel.fromJson(obj);
  }

  /// PATCH /ct/vehicles/{id}
  /// Met à jour un véhicule existant.
  Future<VehicleModel> updateVehicle(String id, Map<String, dynamic> data) async {
    final res = await _api.patch('/ct/vehicles/$id', data: data);
    final obj = _extractObject(res.data, key: 'data');
    return VehicleModel.fromJson(obj);
  }

  /// DELETE /ct/vehicles/{id}
  Future<void> deleteVehicle(String id) async {
    await _api.delete('/ct/vehicles/$id');
  }

  // ── Centres techniques ─────────────────────────────────────────────────

  /// GET /ct/centers
  ///
  /// Paramètres :
  ///   - [date] : YYYY-MM-DD (défaut : aujourd'hui)
  ///   - [lat], [lng] : position pour tri par distance (optionnel)
  ///   - [operatorIds] : filtre sur les opérateurs (utilisé après acceptation
  ///     d'un devis — ne garde que les centres proposés)
  Future<List<TechnicalCenterModel>> getCenters({
    String? date,
    double? lat,
    double? lng,
    List<String>? operatorIds,
  }) async {
    final Map<String, dynamic> params = {
      if (date != null) 'date': date,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };

    // Format Laravel attendu : operator_ids[]=aaa&operator_ids[]=bbb
    // Dio sérialise correctement un List<String> comme tableau PHP.
    if (operatorIds != null && operatorIds.isNotEmpty) {
      params['operator_ids'] = operatorIds;
    }

    final res = await _api.get('/ct/centers', params: params);
    final list = _extractList(res.data, key: 'data');
    return list
        .whereType<Map<String, dynamic>>()
        .map(TechnicalCenterModel.fromJson)
        .toList();
  }

  /// GET /ct/centers/{id}/slots
  /// Liste les créneaux disponibles d'un centre pour une date.
  Future<List<SessionSlotModel>> getAvailableSlots(
    String centerId,
    String date,
  ) async {
    final res = await _api.get(
      '/ct/centers/$centerId/slots',
      params: {'date': date},
    );
    final list = _extractList(res.data, key: 'data');
    return list
        .whereType<Map<String, dynamic>>()
        .map(SessionSlotModel.fromJson)
        .toList();
  }

  // ── Réservations ───────────────────────────────────────────────────────

  /// POST /ct/bookings
  /// Crée une réservation. Statut initial : `pending_payment`.
  /// Le paiement réel se fait ensuite via [initiatePayment].
  Future<CtBookingModel> initiateBooking({
    required String vehicleId,
    required String sessionId,
    String? transportOption,
    String? quoteId,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
    String? returnAddress,
  }) async {
    final res = await _api.post('/ct/bookings', data: {
      'vehicle_id': vehicleId,
      'session_id': sessionId,
      if (transportOption != null) 'transport_mode': transportOption,
      if (quoteId != null) 'quote_id': quoteId,
      if (pickupAddress != null && pickupAddress.isNotEmpty)
        'pickup_address': pickupAddress,
      if (pickupLat != null) 'pickup_lat': pickupLat,
      if (pickupLng != null) 'pickup_lng': pickupLng,
      if (returnAddress != null && returnAddress.isNotEmpty)
        'return_address': returnAddress,
    });
    final obj = _extractObject(res.data, key: 'data');
    return CtBookingModel.fromJson(obj);
  }

  /// POST /ct/bookings/{id}/pay
  ///
  /// Lance le paiement DigitalPaye.
  /// [phone] est obligatoire pour Wave, Orange Money et MTN Money.
  /// Ignoré pour `card`.
  Future<Map<String, dynamic>> initiatePayment(
    String bookingId, {
    required String paymentMethod,
    String? phone,
  }) async {
    final res = await _api.post(
      '/ct/bookings/$bookingId/pay',
      data: {
        'payment_method': paymentMethod,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// GET /ct/bookings
  /// Liste toutes les réservations du client.
  Future<List<CtBookingModel>> getMyBookings() async {
    final res = await _api.get('/ct/bookings');
    final list = _extractList(res.data, key: 'data');
    return list
        .whereType<Map<String, dynamic>>()
        .map(CtBookingModel.fromJson)
        .toList();
  }

  /// GET /ct/bookings/{id}
  Future<CtBookingModel> getBooking(String bookingId) async {
    final res = await _api.get('/ct/bookings/$bookingId');
    final obj = _extractObject(res.data, key: 'data');
    return CtBookingModel.fromJson(obj);
  }

  /// POST /ct/bookings/{id}/cancel
  Future<void> cancelBooking(String bookingId) async {
    await _api.post('/ct/bookings/$bookingId/cancel');
  }

  // ── QR Code ────────────────────────────────────────────────────────────

  /// URL de l'image QR code pour un booking confirmé (bearer auth via header).
  String qrCodeUrl(String bookingId) =>
      '$_base/ct/bookings/$bookingId/qr';

  /// POST /ct/bookings/{id}/regenerate-qr
  ///
  /// Regénère le QR token d'une réservation expirée.
  /// Retourne {qr_token, qr_expires_at, qr_regeneration_count, qr_regeneration_left}.
  Future<Map<String, dynamic>> regenerateQr(String bookingId) async {
    final res = await _api.post('/ct/bookings/$bookingId/regenerate-qr');
    return _extractObject(res.data, key: 'data');
  }
}