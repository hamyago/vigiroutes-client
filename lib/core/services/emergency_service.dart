import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_model.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'location_service.dart';

class EmergencyService {
  EmergencyService._();
  static final EmergencyService instance = EmergencyService._();

  final _api      = ApiService.instance;
  final _location = LocationService();

  Future<EmergencyAlert> triggerEmergency({
    required EmergencyType type,
    required UserModel user,
    String? description,
  }) async {
    final pos = await _location.getCurrentPosition();
    double lat = 0, lng = 0;
    String? address;
    if (pos != null) {
      lat     = pos.latitude ?? 0;
      lng     = pos.longitude ?? 0;
      address = await _location.getAddressFromCoords(lat, lng);
    }

    final body = {
      'user_id':    user.id,
      'user_name':  user.name,
      'user_phone': user.phone,
      'type':       type.key,
      'latitude':   lat,
      'longitude':  lng,
      'address':    address,
      'description':description,
    };

    final response = await _api.post('/emergency', data: body);
    final data = response.data as Map<String, dynamic>;
    return EmergencyAlert.fromJson(data['alert'] as Map<String, dynamic>? ?? data);
  }

  Future<void> callEmergencyNumber(EmergencyType type) async {
    final uri = Uri.parse('tel:${type.phoneNumber}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> updateStatus(String alertId, String status) async {
    await _api.patch('/emergency/$alertId', data: {'status': status});
  }
}