import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/models.dart';
import '../../../core/services/alert_service.dart';
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
            final prevStatus = _intervention!.status;
            _intervention = _intervention!.copyWithWs(data);
            final newStatus = _intervention!.status;
            if (prevStatus != newStatus) {
              _onStatusChanged(prevStatus, newStatus);
            }
            notifyListeners();
            debugPrint('[Tracking] Mise à jour WS : ${_intervention!.status}');
          }
        });
  }

  /// Réagit aux changements de statut temps réel.
  void _onStatusChanged(String previous, String current) {
    // Le prestataire vient d'accepter → il est en route vers l'utilisateur.
    if (current == AppConstants.statusAccepted &&
        previous != AppConstants.statusAccepted) {
      AlertService.instance.providerOnTheWay(
        providerName:
            _intervention?.providerName ?? _intervention?.provider?.name,
      );
    }
    // Intervention terminée ou annulée → on coupe toute alerte en cours.
    if (current == AppConstants.statusCompleted ||
        current == AppConstants.statusCancelled) {
      AlertService.instance.stop();
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    AlertService.instance.reset(); // réarme l'alerte pour une prochaine intervention
    super.dispose();
  }
}
