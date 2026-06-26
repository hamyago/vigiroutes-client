import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/realtime_service.dart';

class TrackingController extends ChangeNotifier {
  final _api      = ApiService.instance;
  final _realtime = RealtimeService.instance;

  InterventionModel? _intervention;
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _wsSub;

  InterventionModel? get intervention => _intervention;
  bool get isLoading => _isLoading;
  String? get error  => _error;

  Future<void> init(String interventionId, String userId) async {
    _isLoading = true;
    notifyListeners();

    // 1. Charger l'état initial depuis l'API REST
    try {
      final data = await _api.getIntervention(interventionId);
      _intervention = InterventionModel.fromJson(data);
      _isLoading    = false;
      notifyListeners();
    } catch (e) {
      _error     = 'Impossible de charger l\'intervention.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // 2. S'abonner aux mises à jour WebSocket temps réel
    // Remplace : _db.watchIntervention(id).listen(...)
    _wsSub = _realtime
        .subscribeToIntervention(userId)
        .where((data) => data['id'] == interventionId)
        .listen((data) {
          if (_intervention != null) {
            _intervention = _intervention!.copyWithWs(data);
            notifyListeners();
            debugPrint('[Tracking] Mise à jour WS : ${_intervention!.status}');
          }
        });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    super.dispose();
  }
}
