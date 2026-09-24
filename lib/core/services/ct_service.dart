import 'api_service.dart';
import '../models/vehicle_model.dart';

class CtService {
  CtService._();
  static final CtService instance = CtService._();

  final _api = ApiService.instance;

  static const _base = 'https://api.vigiroutes.com/api';

  // ── Véhicules ──────────────────────────────────────────────────────────────

  Future<List<VehicleModel>> getVehicles() async {
    final res = await _api.get('/ct/vehicles');
    // FIX : défense contre data null ou format inattendu
    final raw = res.data;
    final list = raw is Map ? (raw['data'] as List?) : (raw as List?);
    if (list == null) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => VehicleModel.fromJson(e))
        .toList();
  }

  Future<VehicleModel> createVehicle(Map<String, dynamic> data) async {
    final res = await _api.post('/ct/vehicles', data: data);
    return VehicleModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<VehicleModel> updateVehicle(String id, Map<String, dynamic> data) async {
    final res = await _api.patch('/ct/vehicles/$id', data: data);
    return VehicleModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteVehicle(String id) async {
    await _api.delete('/ct/vehicles/$id');
  }

  // ── Centres techniques ─────────────────────────────────────────────────────

  Future<List<TechnicalCenterModel>> getCenters({
    String? date,
    double? lat,
    double? lng,
  }) async {
    final res = await _api.get('/ct/centers', params: {
      if (date != null) 'date': date,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    // FIX : défense contre data null ou format inattendu
    final raw = res.data;
    final list = raw is Map ? (raw['data'] as List?) : (raw as List?);
    if (list == null) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => TechnicalCenterModel.fromJson(e))
        .toList();
  }

  Future<List<SessionSlotModel>> getAvailableSlots(
      String centerId, String date) async {
    final res = await _api.get(
      '/ct/centers/$centerId/slots',
      params: {'date': date},
    );
    // FIX : défense contre data null
    final raw = res.data;
    final list = raw is Map ? (raw['data'] as List?) : (raw as List?);
    if (list == null) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => SessionSlotModel.fromJson(e))
        .toList();
  }

  // ── Réservations ───────────────────────────────────────────────────────────

  Future<CtBookingModel> initiateBooking({
    required String vehicleId,
    required String sessionId,
    String? transportOption,
  }) async {
    final res = await _api.post('/ct/bookings', data: {
      'vehicle_id': vehicleId,
      'session_id': sessionId,
      if (transportOption != null) 'transport_option': transportOption,
    });
    return CtBookingModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> initiatePayment(String bookingId) async {
    final res = await _api.post('/ct/bookings/$bookingId/pay');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<CtBookingModel>> getMyBookings() async {
    final res = await _api.get('/ct/bookings');
    // FIX : défense contre data null
    final raw = res.data;
    final list = raw is Map ? (raw['data'] as List?) : (raw as List?);
    if (list == null) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => CtBookingModel.fromJson(e))
        .toList();
  }

  Future<CtBookingModel> getBooking(String bookingId) async {
    final res = await _api.get('/ct/bookings/$bookingId');
    return CtBookingModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> cancelBooking(String bookingId) async {
    await _api.post('/ct/bookings/$bookingId/cancel');
  }

  // ── QR Code ────────────────────────────────────────────────────────────────

  /// URL de l'image QR code pour un booking confirmé (bearer auth via header).
  String qrCodeUrl(String bookingId) =>
      '$_base/ct/bookings/$bookingId/qr';
}
