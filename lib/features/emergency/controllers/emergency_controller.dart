import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/models/emergency_model.dart';
import '../../../core/models/models.dart';
import '../../../core/services/emergency_service.dart';

enum EmergencyState { idle, countdown, sending, done, webFallback, error }

class EmergencyController extends ChangeNotifier {
  final _service = EmergencyService.instance;

  EmergencyState _state = EmergencyState.idle;
  EmergencyType? _selectedType;
  int _countdown = 30;
  Timer? _timer;
  String? _alertId;
  String? _errorMessage;
  // AJOUTÉ : détail facultatif que la personne peut taper PENDANT le
  // compte à rebours (qui continue en arrière-plan, sans jamais bloquer
  // ni ralentir l'envoi si elle n'a pas le temps/l'envie d'écrire).
  String? _description;

  EmergencyState get state => _state;
  EmergencyType? get selectedType => _selectedType;
  int get countdown => _countdown;
  String? get alertId => _alertId;
  String? get errorMessage => _errorMessage;

  void setDescription(String value) {
    _description = value.trim().isEmpty ? null : value.trim();
  }

  bool get isCountingDown => _state == EmergencyState.countdown;
  bool get isDone => _state == EmergencyState.done;

  void startCountdown(EmergencyType type) {
    _selectedType = type;
    _countdown = 30;
    _state = EmergencyState.countdown;
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        _triggerEmergency();
      } else {
        _countdown--;
        notifyListeners();
      }
    });
  }

  void cancelCountdown() {
    _timer?.cancel();
    _state = EmergencyState.idle;
    _selectedType = null;
    _countdown = 30;
    _description = null;
    notifyListeners();
  }

  void triggerNow() {
    _timer?.cancel();
    _triggerEmergency();
  }

  Future<void> _triggerEmergency() async {
    if (_selectedType == null || _currentUser == null) return;
    _state = EmergencyState.sending;
    notifyListeners();

    try {
      _alertId = (await _service.triggerEmergency(
        type: _selectedType!,
        user: _currentUser!,
        description: _description,
      )).id;

      // Sur web desktop, l'appel tel: ne fonctionne pas —
      // on bascule sur un écran de repli avec le numéro affiché.
      if (kIsWeb) {
        _state = EmergencyState.webFallback;
      } else {
        _state = EmergencyState.done;
      }
    } catch (e) {
      // Sur web, même en cas d'erreur réseau, on affiche le numéro
      if (kIsWeb) {
        _state = EmergencyState.webFallback;
      } else {
        _errorMessage = 'Erreur lors de l\'envoi de l\'alerte. '
            'Appelez directement le ${_selectedType!.phoneNumber}.';
        _state = EmergencyState.error;
      }
    }
    notifyListeners();
  }

  Future<void> shareLocation() async {
    if (_selectedType == null) return;
    await _service.callEmergencyNumber(_selectedType!);
  }

  void reset() {
    _timer?.cancel();
    _state = EmergencyState.idle;
    _selectedType = null;
    _countdown = 30;
    _alertId = null;
    _errorMessage = null;
    _description = null;
    notifyListeners();
  }

  UserModel? _currentUser;
  void setUser(UserModel user) => _currentUser = user;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
