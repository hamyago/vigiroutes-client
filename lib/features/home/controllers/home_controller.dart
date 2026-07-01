import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/service_type_service.dart';
import '../../../core/models/service_type_model.dart';

const _serviceColors = {
  'depannage':  Color(0xFFFF6B35),
  'remorquage': Color(0xFF4299E1),
  'pneu':       Color(0xFF48BB78),
  'batterie':   Color(0xFF9F7AEA),
  'carburant':  Color(0xFFFC8181),
  'serrurier':  Color(0xFF68D391),
  'other':      Color(0xFF63B3ED),
};

const _serviceEmojis = {
  'depannage':  '🔧',
  'remorquage': '🚛',
  'pneu':       '🔩',
  'batterie':   '🔋',
  'carburant':  '⛽',
  'serrurier':  '🔑',
  'other':      '🛠️',
};

class HomeController extends ChangeNotifier {
  final _api       = ApiService.instance;
  final _location  = LocationService();
  final _stService = ServiceTypeService.instance;

  LatLng?             _userPosition;
  bool                _locationApprox = false;
  List<ProviderModel> _providers    = [];
  Set<Marker>         _markers      = {};
  String?             _serviceFilter;
  bool                _isLoading    = true;
  String?             _error;
  Timer?              _refreshTimer;

  LatLng?                get userPosition        => _userPosition;
  bool                   get locationApprox      => _locationApprox;
  List<ProviderModel>    get providers           => _providers;
  Set<Marker>            get markers             => _markers;

  // Recherche par nom (barre de recherche de la carte)
  String _search = '';
  String get search => _search;
  void setSearchQuery(String q) {
    _search = q;
    notifyListeners();
  }

  /// Prestataires réellement affichés dans la liste (après filtre de recherche).
  List<ProviderModel> get visibleProviders {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _providers;
    return _providers.where((p) => p.name.toLowerCase().contains(q)).toList();
  }
  String?                get serviceFilter       => _serviceFilter;
  String?                get selectedServiceFilter => _serviceFilter;
  bool                   get isLoading           => _isLoading;
  String?                get error               => _error;
  List<ServiceTypeModel> get serviceTypes        => _stService.serviceTypes;
  bool                   get servicesLoading     => _stService.isLoading;

  /// Centre d'Abidjan — utilisé comme position de repli pour que la carte
  /// s'affiche même si le GPS est refusé / coupé / trop lent.
  static const LatLng _abidjan = LatLng(5.3599517, -4.0082563);

  Future<void> initialize() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    await _stService.load();

    final pos = await _location.getCurrentPosition();
    if (pos != null) {
      _userPosition   = LatLng(pos.latitude, pos.longitude);
      _locationApprox = false;
    } else {
      // Repli : la carte doit toujours s'afficher.
      _userPosition   = _abidjan;
      _locationApprox = true;
    }
    _isLoading = false;
    notifyListeners();

    await _loadProviders();
    _refreshTimer ??=
        Timer.periodic(const Duration(seconds: 30), (_) => _loadProviders());
  }

  /// Relance la détection GPS (bouton « ma position »). Retourne la nouvelle
  /// position si obtenue, sinon null.
  Future<LatLng?> refreshLocation() async {
    final pos = await _location.getCurrentPosition();
    if (pos != null) {
      _userPosition   = LatLng(pos.latitude, pos.longitude);
      _locationApprox = false;
      notifyListeners();
      await _loadProviders();
      return _userPosition;
    }
    return null;
  }

  void setServiceFilter(String? id) {
    _serviceFilter = id;
    notifyListeners();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    if (_userPosition == null) return;
    try {
      final data = await _api.getNearbyProviders(
        latitude:      _userPosition!.latitude,
        longitude:     _userPosition!.longitude,
        serviceTypeId: _serviceFilter,
      );
      _providers = data.map((e) => ProviderModel.fromJson(e as Map<String, dynamic>)).toList();
      await _buildMarkers();
    } catch (e) {
      debugPrint('[HomeController] $e');
    }
  }

  String _resolveSlug(String id) {
    final byId   = _stService.findById(id);
    if (byId   != null) return byId.slug;
    final bySlug = _stService.findBySlug(id);
    if (bySlug != null) return bySlug.slug;
    return 'other';
  }

  Future<void> _buildMarkers() async {
    final markers = <Marker>{};

    if (_userPosition != null) {
      final icon = await _getCachedIcon('__client__', null);
      markers.add(Marker(
        markerId:  const MarkerId('__client__'),
        position:  _userPosition!,
        icon:      icon,
        infoWindow: const InfoWindow(title: '📍 Votre position'),
        zIndex:    2,
      ));
    }

    for (final p in _providers) {
      final slug = _resolveSlug(p.serviceTypes.isNotEmpty ? p.serviceTypes.first : 'other');
      final icon = await _getCachedIcon(p.id, slug);
      final dist = p.distanceKm != null ? ' · ${p.distanceKm!.toStringAsFixed(1)} km' : '';
      markers.add(Marker(
        markerId:  MarkerId(p.id),
        position:  LatLng(p.latitude, p.longitude),
        icon:      icon,
        infoWindow: InfoWindow(title: '🟢 ${p.name}', snippet: '${p.rating.toStringAsFixed(1)}★$dist'),
      ));
    }

    _markers = markers;
    notifyListeners();
  }

  final Map<String, BitmapDescriptor> _iconCache = {};

  Future<BitmapDescriptor> _getCachedIcon(String id, String? slug) async {
    if (_iconCache.containsKey(id)) return _iconCache[id]!;
    final icon = id == '__client__' ? await _buildClientMarker() : await _buildProviderMarker(slug ?? 'other');
    _iconCache[id] = icon;
    return icon;
  }

  Future<BitmapDescriptor> _buildClientMarker() async {
    if (kIsWeb) return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    const color = Color(0xFF1A56DB);
    const size  = 80.0;
    final rec    = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawCircle(const Offset(size/2,size/2-4),34,Paint()..color=color.withValues(alpha:0.15));
    canvas.drawCircle(const Offset(size/2,size/2-4),28,Paint()..color=color);
    canvas.drawCircle(const Offset(size/2,size/2-4),28,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=4);
    final path = Path()..moveTo(size/2-8,size/2+22)..lineTo(size/2,size/2+42)..lineTo(size/2+8,size/2+22)..close();
    canvas.drawPath(path,Paint()..color=color);
    final tp = TextPainter(text:const TextSpan(text:'👤',style:TextStyle(fontSize:22)),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,Offset(size/2-tp.width/2,size/2-4-tp.height/2));
    final img   = await rec.endRecording().toImage(size.toInt(),(size+10).toInt());
    final bytes = await img.toByteData(format:ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),width:44,height:50);
  }

  Future<BitmapDescriptor> _buildProviderMarker(String slug) async {
    if (kIsWeb) {
      final hue = HSVColor.fromColor(_serviceColors[slug]??const Color(0xFFFF6B35)).hue;
      return BitmapDescriptor.defaultMarkerWithHue(hue);
    }
    final color = _serviceColors[slug] ?? const Color(0xFFFF6B35);
    const size  = 80.0;
    final rec    = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawCircle(const Offset(size/2+2,size/2+4),28,Paint()..color=Colors.black.withValues(alpha:0.2)..maskFilter=const MaskFilter.blur(BlurStyle.normal,4));
    canvas.drawCircle(const Offset(size/2,size/2-4),28,Paint()..color=color);
    canvas.drawCircle(const Offset(size/2,size/2-4),28,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=3);
    final path = Path()..moveTo(size/2-8,size/2+22)..lineTo(size/2,size/2+42)..lineTo(size/2+8,size/2+22)..close();
    canvas.drawPath(path,Paint()..color=color);
    final emoji = _serviceEmojis[slug]??'🛠️';
    final tp = TextPainter(text:TextSpan(text:emoji,style:const TextStyle(fontSize:22)),textDirection:TextDirection.ltr)..layout();
    tp.paint(canvas,Offset(size/2-tp.width/2,size/2-4-tp.height/2));
    canvas.drawCircle(Offset(size/2+20,size/2-24),8,Paint()..color=Colors.green.shade400);
    canvas.drawCircle(Offset(size/2+20,size/2-24),8,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=2);
    final img   = await rec.endRecording().toImage(size.toInt(),(size+10).toInt());
    final bytes = await img.toByteData(format:ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),width:40,height:45);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
