import '../models/ct_quote_model.dart';
import 'api_service.dart';

class CtQuoteService {
  CtQuoteService._();
  static final instance = CtQuoteService._();

  final _api = ApiService.instance;

  /// GET /client/ct/quote-requests
  Future<List<CtQuoteRequestModel>> getMyRequests() async {
    final res = await _api.get('/client/ct/quote-requests');
    final data = res.data['data'] as List<dynamic>;
    return data
        .map((e) => CtQuoteRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /client/ct/quote-requests/{id}
  Future<CtQuoteRequestModel> getRequest(String id) async {
    final res = await _api.get('/client/ct/quote-requests/$id');
    return CtQuoteRequestModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// POST /client/ct/quote-requests
  Future<CtQuoteRequestModel> createRequest({
    required String vehicleId,
    required String transportMode,
    String? notes,
  }) async {
    final res = await _api.post('/client/ct/quote-requests', data: {
      'vehicle_id': vehicleId,
      'transport_mode': transportMode,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return CtQuoteRequestModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// POST /client/ct/quote-requests/{id}/respond
  /// Returns [CtBookingHint] when decision == 'accepted', null otherwise.
  Future<CtBookingHint?> respond(String id, String decision) async {
    final res = await _api.post('/client/ct/quote-requests/$id/respond', data: {
      'decision': decision,
    });
    final hint = res.data['data']?['booking_hint'];
    if (hint != null) {
      return CtBookingHint.fromJson(hint as Map<String, dynamic>);
    }
    return null;
  }
}
