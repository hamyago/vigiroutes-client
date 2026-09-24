import 'dart:async';
import 'dart:math' show asin, cos, pi, sin, sqrt;
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

  // FIX bug 1 : mémoriser la dernière position envoyée à checkAndNotify
  // pour éviter de déclencher la détection de ville à chaque polling.
  // On ne notifie le backend que si l'utilisateur s'est déplacé de plus
  // de _cityCheckThresholdKm depuis le dernier envoi.
  LatLng?  _lastCityCheckPosition;
  static const double _cityCheckThresholdKm = 5.0;

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

    try {
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

      // FIX bug 1 : premier chargement — toujours envoyer la position
      // au backend pour la détection de ville (premier appel au démarrage).
      await _loadProviders(checkCity: true);

      // FIX bug 1 : le timer de 30 s rafraîchit UNIQUEMENT les prestataires
      // sur la carte (marqueurs, disponibilité). Il ne déclenche PAS la
      // détection de ville à chaque tick — checkCity vaut false ici.
      // La détection de ville se fait seulement si l'utilisateur s'est
      // déplacé de plus de _cityCheckThresholdKm (voir _shouldCheckCity).
      _refreshTimer ??=
          Timer.periodic(const Duration(seconds: 30), (_) => _loadProviders(checkCity: false));
    } catch (e) {
      // Filet de sécurité : ne doit jamais laisser l'écran figé sur un
      // spinner indéfiniment sans retour possible.
      debugPrint('[HomeController] initialize error: $e');
      _userPosition   = _abidjan;
      _locationApprox = true;
      _isLoading      = false;
      notifyListeners();
    }
  }

  /// Relance la détection GPS (bouton « ma position »). Retourne la nouvelle
  /// position si obtenue, sinon null.
  Future<LatLng?> refreshLocation() async {
    final pos = await _location.getCurrentPosition();
    if (pos != null) {
      _userPosition   = LatLng(pos.latitude, pos.longitude);
      _locationApprox = false;
      notifyListeners();
      // FIX bug 1 : un appui sur "ma position" peut signifier un vrai
      // déplacement — on réévalue la ville si le seuil est franchi.
      await _loadProviders(checkCity: true);
      return _userPosition;
    }
    return null;
  }

  void setServiceFilter(String? id) {
    _serviceFilter = id;
    notifyListeners();
    // Changement de filtre = pas un déplacement → pas de détection de ville
    _loadProviders(checkCity: false);
  }

  /// Calcule si l'utilisateur s'est suffisamment déplacé par rapport à la
  /// dernière position envoyée au backend pour valoir une nouvelle détection
  /// de ville. Utilise la formule de Haversine (distance en km).
  bool _shouldCheckCity(LatLng current) {
    if (_lastCityCheckPosition == null) return true; // premier appel
    return _haversineKm(_lastCityCheckPosition!, current) >= _cityCheckThresholdKm;
  }

  /// Distance Haversine entre deux coordonnées, en kilomètres.
  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0; // rayon terrestre moyen en km
    final dLat = _deg2rad(b.latitude  - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2)
        + cos(_deg2rad(a.latitude))
        * cos(_deg2rad(b.latitude))
        * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(h));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  Future<void> _loadProviders({required bool checkCity}) async {
    if (_userPosition == null) return;

    // FIX bug 1 : on décide ICI si on doit déclencher checkAndNotify.
    // - checkCity == true  : l'appelant veut explicitement une vérification
    //   (démarrage, appui "ma position") — on vérifie quand même le seuil
    //   pour éviter un double-envoi si refreshLocation() est appelé deux fois
    //   rapidement.
    // - checkCity == false : appel périodique ou changement de filtre — on
    //   ne vérifie jamais la ville, quel que soit le déplacement.
    final doCheckCity = checkCity && _shouldCheckCity(_userPosition!);

    try {
      final data = await _api.getNearbyProviders(
        latitude:      _userPosition!.latitude,
        longitude:     _userPosition!.longitude,
        serviceTypeId: _serviceFilter,
        // FIX bug 1 : on passe un flag au service API qui décide d'inclure
        // ou non le paramètre skip_city_check dans la requête.
        // Quand doCheckCity == false, on indique au backend de ne PAS
        // appeler checkAndNotify, évitant ainsi l'envoi répété de la notif.
        skipCityCheck: !doCheckCity,
      );
      _providers = data.map((e) => ProviderModel.fromJson(e as Map<String, dynamic>)).toList();

      if (doCheckCity) {
        _lastCityCheckPosition = _userPosition;
        debugPrint('[HomeController] Détection de ville envoyée (déplacement ≥ ${_cityCheckThresholdKm}km ou premier appel)');
      }

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
        zIndexInt:  2,
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
