import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  LocationData({required this.latitude, required this.longitude, this.accuracy});
}

class LocationService {
  Future<LocationData?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[Location] GPS desactive');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[Location] Permission refusee');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('[Location] Permission refusee definitivement');
        return null;
      }

      // Acquisition GPS avec délai large ; en cas de timeout on retombe
      // sur la dernière position connue (instantanée) si elle existe.
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) return null;
        pos = last;
      }
      return LocationData(latitude: pos.latitude, longitude: pos.longitude, accuracy: pos.accuracy);
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
