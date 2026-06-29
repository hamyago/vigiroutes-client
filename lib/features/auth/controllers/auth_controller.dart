import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/realtime_service.dart';

enum AuthState { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  final _firebaseAuth = FirebaseAuth.instance;
  final _api          = ApiService.instance;

  AuthState  _state          = AuthState.unknown;
  UserModel? _user;
  bool       _isLoading      = false;
  String?    _error;
  String?    _verificationId;

  AuthState  get state      => _state;
  UserModel? get user       => _user;
  bool       get isLoading  => _isLoading;
  String?    get error      => _error;
  bool       get isUser     => _user != null;
  bool       get isProvider => false;
  String?    get role       => _user != null ? 'user' : null;
  bool       get otpSent    => _verificationId != null;

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
    final hasToken     = await _api.hasToken;
    final firebaseUser = _firebaseAuth.currentUser;
    if (hasToken && firebaseUser != null) {
      await _refreshUser(firebaseUser);
    } else {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    _isLoading      = true;
    _error          = null;
    _verificationId = null;
    notifyListeners();

    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          debugPrint('[Auth] verificationCompleted — auto sign-in');
          await _signIn(credential);
        },
        verificationFailed: (e) {
          debugPrint('[Auth] verificationFailed: ${e.code} — ${e.message}');
          _error     = _friendlyFirebaseError(e.code, e.message);
          _isLoading = false;
          notifyListeners();
        },
        codeSent: (id, resendToken) {
          debugPrint('[Auth] codeSent — verificationId recu');
          _verificationId = id;
          _isLoading      = false;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (id) {
          debugPrint('[Auth] codeAutoRetrievalTimeout');
          _verificationId ??= id;
        },
      );
    } catch (e) {
      debugPrint('[Auth] sendOtp exception: $e');
      _error     = 'Erreur inattendue lors de l\'envoi du code.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp(String phone) => sendOtp(phone);

  Future<bool> verifyOtp(String otp) async {
    if (_verificationId == null) {
      _error = 'Session expirée. Veuillez renvoyer le code.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error     = null;
    notifyListeners();
    return _signIn(PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    ));
  }

  Future<bool> _signIn(AuthCredential credential) async {
    try {
      final uc      = await _firebaseAuth.signInWithCredential(credential);
      final idToken = await uc.user!.getIdToken(false);
      final fcmToken = await FirebaseMessaging.instance.getToken();

      // Sauvegarder le token Firebase
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('firebase_token', idToken!);

      final response = await _api.loginUser(
        firebaseToken: idToken,
        fcmToken:      fcmToken,
        phone:         uc.user!.phoneNumber,
      );

      _user      = UserModel.fromJson(response['user'] as Map<String, dynamic>);
      _state     = AuthState.authenticated;
      _isLoading = false;
      await RealtimeService.instance.init(response['token'] as String);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] signIn error: ${e.code}');
      _error     = _friendlyFirebaseError(e.code, e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[Auth] signIn error: $e');
      _error     = 'Impossible de se connecter au serveur.';
      _isLoading = false;
      _state     = AuthState.unauthenticated;
      notifyListeners();
      return false;  // ← était true (bug silencieux : succès affiché alors que le login a échoué)
    }
  }

  Future<void> _refreshUser(User firebaseUser,
      {String? name, String? phone}) async {
    try {
      // getIdToken(false) — pas de refresh réseau forcé
      final idToken  = await firebaseUser.getIdToken(false);
      final fcmToken = await FirebaseMessaging.instance.getToken();

      // Sauvegarder le token Firebase
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('firebase_token', idToken!);

      final response = await _api.loginUser(
        firebaseToken: idToken,
        name:          name,
        phone:         phone ?? firebaseUser.phoneNumber,
        fcmToken:      fcmToken,
      );

      _user      = UserModel.fromJson(response['user'] as Map<String, dynamic>);
      _state     = AuthState.authenticated;
      _isLoading = false;
      await RealtimeService.instance.init(response['token'] as String);
      notifyListeners();
    } catch (e) {
      debugPrint('[Auth] _refreshUser error: $e');
      _error     = 'Impossible de se connecter au serveur.';
      _isLoading = false;
      _state     = AuthState.unauthenticated;
      notifyListeners();
    }
  }

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
      await refreshUser(); // GET /user/me → _user à jour, state authenticated
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

  /// Recharge le profil depuis GET /user/me (sans repasser par le login,
  /// pour ne pas risquer d'écraser des champs). Propage l'erreur afin que
  /// les écrans appelants puissent l'afficher.
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
    await _firebaseAuth.signOut();
    await RealtimeService.instance.disconnect();
    _user  = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  String _friendlyFirebaseError(String code, String? defaultMsg) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide. Vérifiez le format (+225...).';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 'invalid-verification-code':
        return 'Code incorrect. Vérifiez le SMS et réessayez.';
      case 'session-expired':
        return 'Session expirée. Veuillez renvoyer le code.';
      case 'network-request-failed':
        return 'Pas de connexion réseau. Vérifiez votre connexion.';
      case 'billing-not-enabled':
        return 'Service SMS non activé. Contactez le support.';
      case 'operation-not-allowed':
        return 'Authentification par SMS non activée dans Firebase Console.';
      default:
        return defaultMsg ?? 'Une erreur est survenue. Réessayez.';
    }
  }
}
