import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';

class LocationService {
  final _location = Location();

  Future<LocationData?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return null;
      }

      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) return null;
      }

      return await _location.getLocation();
    } catch (e) {
      debugPrint('[Location] Error: $e');
      return null;
    }
  }

  Stream<LocationData> positionStream() => _location.onLocationChanged;

  // Reverse geocoding simplifié — on retourne les coordonnées formatées
  // car geocoding a le même bug v1 embedding que geolocator
  Future<String?> getAddressFromCoords(double lat, double lng) async {
    try {
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    } catch (_) {
      return null;
    }
  }

  double distanceBetween(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;
}
