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
    return (res.data['data'] as List)
        .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<VehicleModel> createVehicle(Map<String, dynamic> data) async {
    final res = await _api.post('/ct/vehicles', data: data);
    return VehicleModel.fromJson(res.data['data']);
  }

  Future<VehicleModel> updateVehicle(String id, Map<String, dynamic> data) async {
    final res = await _api.patch('/ct/vehicles/$id', data: data);
    return VehicleModel.fromJson(res.data['data']);
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
    return (res.data['data'] as List)
        .map((e) => TechnicalCenterModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SessionSlotModel>> getAvailableSlots(
      String centerId, String date) async {
    final res = await _api.get(
      '/ct/centers/$centerId/slots',
      params: {'date': date},
    );
    return (res.data['data'] as List)
        .map((e) => SessionSlotModel.fromJson(e as Map<String, dynamic>))
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
    return CtBookingModel.fromJson(res.data['data']);
  }

  Future<Map<String, dynamic>> initiatePayment(String bookingId) async {
    final res = await _api.post('/ct/bookings/$bookingId/pay');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<CtBookingModel>> getMyBookings() async {
    final res = await _api.get('/ct/bookings');
    return (res.data['data'] as List)
        .map((e) => CtBookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── QR Code ────────────────────────────────────────────────────────────────

  /// URL de l'image QR code pour un booking confirmé (bearer auth via header).
  String qrCodeUrl(String bookingId) =>
      '$_base/ct/bookings/$bookingId/qr';
}
