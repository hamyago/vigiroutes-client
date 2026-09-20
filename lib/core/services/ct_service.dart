// ignore_for_file: always_specify_types
import '../models/vehicle_model.dart';
import 'api_service.dart';

class CtService {
  static final CtService instance = CtService._();
  CtService._();

  // ── Vehicles ──────────────────────────────────────────────────────────────

  Future<List<VehicleModel>> getMyVehicles() async {
    final res = await ApiService.instance.get('/v1/vehicles');
    final d = res.data;
    final List raw = (d is Map ? (d['data'] ?? d['vehicles']) : d) as List? ?? [];
    return raw.map((e) => VehicleModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<VehicleModel>> getVehicles() => getMyVehicles();

  // ── Centers ───────────────────────────────────────────────────────────────

  Future<List<TechnicalCenterModel>> getCenters({
    String? date,
    double? lat,
    double? lng,
    String vehicleCategory = 'VP',
  }) async {
    final res = await ApiService.instance.get('/v1/ct/centers', params: {
      'vehicle_category': vehicleCategory,
      if (date != null) 'date': date,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
    final d = res.data;
    final List raw = (d is Map ? (d['data'] ?? d['centers']) : d) as List? ?? [];
    return raw.map((e) => TechnicalCenterModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Slots ─────────────────────────────────────────────────────────────────

  Future<List<SessionSlotModel>> getAvailableSlots(String centerId, String date) async {
    final res = await ApiService.instance.get(
      '/v1/ct/centers/$centerId/slots',
      params: {'date': date},
    );
    final d = res.data;
    final List raw = (d is Map ? (d['data'] ?? d['slots']) : d) as List? ?? [];
    return raw.map((e) => SessionSlotModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Bookings ──────────────────────────────────────────────────────────────

  Future<CtBookingModel> initiateBooking({
    required String vehicleId,
    required String sessionId,
    required String slotTime,
    required String vehicleCategory,
    required String transportMode,
    bool keyHandoverAccepted = false,
    String? pickupAddress,
    double? pickupLat,
    double? pickupLng,
  }) async {
    final res = await ApiService.instance.post('/v1/ct/bookings/initiate', data: {
      'vehicle_id': vehicleId,
      'session_id': sessionId,
      'slot_time': slotTime,
      'vehicle_category': vehicleCategory,
      'transport_mode': transportMode,
      'key_handover_accepted': keyHandoverAccepted,
      if (pickupAddress != null) 'pickup_address': pickupAddress,
      if (pickupLat != null) 'pickup_lat': pickupLat,
      if (pickupLng != null) 'pickup_lng': pickupLng,
    });
    final d = res.data;
    final map = (d is Map && d['data'] is Map) ? d['data'] : d;
    return CtBookingModel.fromJson(map as Map<String, dynamic>);
  }

  Future<List<CtBookingModel>> getMyBookings() async {
    final res = await ApiService.instance.get('/v1/ct/bookings');
    final d = res.data;
    final List raw = (d is Map ? (d['data'] ?? d['bookings'] ?? d['data']) : d) as List? ?? [];
    return raw.map((e) => CtBookingModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CtBookingModel> getBooking(String id) async {
    final res = await ApiService.instance.get('/v1/ct/bookings/$id');
    final d = res.data;
    final map = (d is Map && d['data'] is Map) ? d['data'] : d;
    return CtBookingModel.fromJson(map as Map<String, dynamic>);
  }

  Future<void> cancelBooking(String id) async {
    await ApiService.instance.delete('/v1/ct/bookings/$id');
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> initiatePayment(
    String bookingId, {
    required String paymentMethod,
    String? phone,
  }) async {
    final res = await ApiService.instance.post(
      '/v1/ct/bookings/$bookingId/pay',
      data: {
        'payment_method': paymentMethod,
        if (phone != null) 'phone': phone,
      },
    );
    final d = res.data;
    return ((d is Map && d['data'] is Map) ? d['data'] : d) as Map<String, dynamic>? ?? {};
  }

  String qrCodeUrl(String bookingId) =>
      'https://api.vigiroutes.com/api/v1/ct/bookings/$bookingId/qr';

  // ── Carnet numérique ───────────────────────────────────────────────────────

  Future<List<VehicleInterventionModel>> getVehicleHistory(String vehicleId) async {
    final res = await ApiService.instance.get('/v1/vehicles/$vehicleId/history');
    final d = res.data;
    final List raw = (d is Map ? (d['data'] ?? d['history']) : d) as List? ?? [];
    return raw.map((e) => VehicleInterventionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getSpendingSummary(String vehicleId) async {
    final res = await ApiService.instance.get('/v1/vehicles/$vehicleId/spending');
    final d = res.data;
    return ((d is Map && d['data'] is Map) ? d['data'] : d) as Map<String, dynamic>? ?? {};
  }
}
