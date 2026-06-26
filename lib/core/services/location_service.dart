import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  LocationData({required this.latitude, required this.longitude, this.accuracy});
}

class LocationService {
  static const _channel = MethodChannel('ci.oyopmt.vigiroutes/location');

  Future<LocationData?> getCurrentPosition() async {
    try {
      final hasPermission = await _channel.invokeMethod<bool>('checkPermission') ?? false;
      if (!hasPermission) {
        await _channel.invokeMethod('requestPermission');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      final result = await _channel.invokeMethod<Map>('getCurrentPosition');
      if (result == null) return null;
      return LocationData(
        latitude:  (result['latitude']  as num).toDouble(),
        longitude: (result['longitude'] as num).toDouble(),
        accuracy:  (result['accuracy']  as num?)?.toDouble(),
      );
    } catch (e) {
      debugPrint('[Location] error: $e');
      return null;
    }
  }

  Stream<LocationData> positionStream() => const Stream.empty();

  Future<String?> getAddressFromCoords(double lat, double lng) async {
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  double distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;
}
