import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/realtime_service.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  final _api = ApiService.instance;

  AuthState  _state     = AuthState.unknown;
  UserModel? _user;
  bool       _isLoading = false;
  String?    _error;
  bool       _otpSent   = false;

  /// Numéro de téléphone pour lequel l'OTP a été envoyé.
  String? _otpPhone;

  AuthState  get state      => _state;
  UserModel? get user       => _user;
  bool       get isLoading  => _isLoading;
  String?    get error      => _error;
  bool       get isUser     => _user != null;
  bool       get isProvider => false;
  String?    get role       => _user != null ? 'user' : null;
  bool       get otpSent    => _otpSent;

  /// Vrai quand l'utilisateur est connecté mais n'a pas encore renseigné
  /// son nom (nouveau compte). Sert à l'envoyer vers l'écran de création
  /// de profil après l'OTP.
  bool get needsProfileSetup {
    final n = _user?.name.trim() ?? '';
    if (n.isEmpty) return true;
    if (n.toLowerCase() == 'utilisateur') return true;
    if (n == (_user?.phone ?? '')) return true;
    return false;
  }

  AuthController() {
    _init();
    _api.onUnauthorized = () {
      _state = AuthState.unauthenticated;
      _user  = null;
      notifyListeners();
    };
  }

  Future<void> _init() async {
    final hasToken = await _api.hasToken;
    if (hasToken) {
      await _refreshUser();
    } else {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  OTP via Termii (backend API)
  // ══════════════════════════════════════════════════════════════════════

  /// Envoie un OTP au numéro donné via le backend → Termii.
  Future<void> sendOtp(String phoneNumber) async {
    _isLoading = true;
    _error     = null;
    _otpSent   = false;
    _otpPhone  = phoneNumber;
    notifyListeners();

    try {
      await _api.sendOtp(phoneNumber);
      _otpSent   = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] sendOtp error: $e');
      _error     = _extractError(e, 'Erreur lors de l\'envoi du code.');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp(String phone) => sendOtp(phone);

  /// Vérifie l'OTP saisi et connecte/crée le client.
  Future<bool> verifyOtp(String otp) async {
    if (_otpPhone == null) {
      _error = 'Session expirée. Veuillez renvoyer le code.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      // Récupérer le token FCM (non-bloquant)
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint('[Auth] getToken non-fatal: $e');
      }

      final response = await _api.verifyOtpUser(
        phone:    _otpPhone!,
        otp:      otp,
        fcmToken: fcmToken,
      );

      _user      = UserModel.fromJson(response['user'] as Map<String, dynamic>);
      _state     = AuthState.authenticated;
      _isLoading = false;

      // Initialiser le temps réel si un token est retourné
      final token = response['token'];
      if (token is String && token.isNotEmpty) {
        try {
          await RealtimeService.instance.init(token);
        } catch (e) {
          debugPrint('[Auth] RealtimeService.init non-fatal: $e');
        }
      }

      notifyListeners();
      return true;

    } catch (e) {
      debugPrint('[Auth] verifyOtp error: $e');
      _error     = _extractError(e, 'Code incorrect ou expiré.');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Profil & session
  // ══════════════════════════════════════════════════════════════════════

  Future<void> completeUserProfile(
      {required String name, String? whatsapp}) async {
    _isLoading = true;
    _error     = null;
    notifyListeners();
    try {
      await _api.updateUser({
        'name': name,
        if (whatsapp != null && whatsapp.isNotEmpty) 'whatsapp': whatsapp,
      });
      await refreshUser();
    } catch (e) {
      debugPrint('[Auth] completeUserProfile: $e');
      _error = 'Impossible d\'enregistrer le profil. Réessayez.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeProviderProfile({
    required String name,
    required String phone,
    required List<String> serviceTypes,
    required double latitude,
    required double longitude,
  }) async {}

  /// Recharge le profil depuis GET /user/me.
  Future<void> refreshUser() async {
    try {
      final data = await _api.getMe();
      _user  = UserModel.fromJson(data);
      _state = AuthState.authenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] refreshUser error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await RealtimeService.instance.disconnect();
    _user     = null;
    _state    = AuthState.unauthenticated;
    _otpSent  = false;
    _otpPhone = null;
    notifyListeners();
  }

  // ── Privé ─────────────────────────────────────────────────────────────

  Future<void> _refreshUser() async {
    try {
      final data = await _api.getMe();
      _user  = UserModel.fromJson(data);
      _state = AuthState.authenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] _refreshUser error: $e');
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  /// Extrait un message d'erreur lisible depuis une exception Dio ou autre.
  String _extractError(dynamic e, String fallback) {
    try {
      if (e is Exception && e.toString().contains('DioException')) {
        // Dio met le message dans response.data['message']
        final dynamic resp = (e as dynamic).response;
        if (resp != null) {
          final data = resp.data;
          if (data is Map && data['message'] != null) {
            return data['message'] as String;
          }
        }
      }
    } catch (_) {}
    return fallback;
  }
}
