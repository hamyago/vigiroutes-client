import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  static const _base = 'https://api.vigiroutes.com/api';
  late final Dio _dio;
  VoidCallback? onUnauthorized;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl:        _base,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();

        // Routes /user/* → Firebase ID token (jamais Sanctum)
        // Routes /provider/* → Firebase ID token
        // Routes /auth/* → aucun token (login/register)
        // Autres → Sanctum token (admin, etc.)
        final path = options.path;

        if (path.startsWith('/auth/')) {
          // Pas de token sur les routes d'authentification
        } else if (path.startsWith('/user/') || path.startsWith('/provider/')) {
          // Firebase ID token — toujours frais depuis Firebase
          String? token;
          try {
            final u = fb.FirebaseAuth.instance.currentUser;
            if (u != null) {
              token = await u.getIdToken(false);
              await prefs.setString('firebase_token', token!);
            } else {
              token = prefs.getString('firebase_token');
            }
          } catch (_) {
            token = prefs.getString('firebase_token');
          }
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
        } else {
          // Sanctum token (routes admin, etc.)
          final token = prefs.getString('sanctum_token');
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
        }

        if (kDebugMode) debugPrint('[API] ${options.method} ${options.path}');
        handler.next(options);
      },
      onError: (err, handler) {
        if (err.response?.statusCode == 401 &&
            !err.requestOptions.path.contains('/auth/')) {
          onUnauthorized?.call();
        }
        handler.next(err);
      },
    ));
  }

  // ── Token ─────────────────────────────────────────────────────────────────
  Future<void> saveToken(String token) async =>
      (await SharedPreferences.getInstance()).setString('sanctum_token', token);

  Future<void> clearToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('sanctum_token');
    await p.remove('firebase_token');
  }

  /// Retourne true si l'utilisateur a un token actif (Sanctum OU Firebase)
  Future<bool> get hasToken async {
    final prefs = await SharedPreferences.getInstance();
    // Vérifier d'abord Sanctum (token API)
    if (prefs.containsKey('sanctum_token')) return true;
    // Sinon vérifier Firebase directement (session active)
    return fb.FirebaseAuth.instance.currentUser != null;
  }

  // ── HTTP ──────────────────────────────────────────────────────────────────
  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);
  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);
  Future<Response> patch(String path, {dynamic data}) => _dio.patch(path, data: data);
  Future<Response> delete(String path) => _dio.delete(path);

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginUser({
    required String firebaseToken,
    String? name, String? phone, String? fcmToken,
  }) async {
    final res = await post('/auth/user/login', data: {
      'firebase_token': firebaseToken,
      if (name     != null) 'name':      name,
      if (phone    != null) 'phone':     phone,
      if (fcmToken != null) 'fcm_token': fcmToken,
    });
    await saveToken(res.data['token'] as String);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loginProvider({
    required String firebaseToken,
    String? name, String? phone, String? fcmToken,
    List<String>? serviceTypes, String? sector,
  }) async {
    final res = await post('/auth/provider/login', data: {
      'firebase_token': firebaseToken,
      if (name         != null) 'name':          name,
      if (phone        != null) 'phone':         phone,
      if (fcmToken     != null) 'fcm_token':     fcmToken,
      if (serviceTypes != null) 'service_types': serviceTypes,
      if (sector       != null) 'sector':        sector,
    });
    await saveToken(res.data['token'] as String);
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try { await post('/auth/logout'); } catch (_) {}
    await clearToken();
  }

  // ── Providers ─────────────────────────────────────────────────────────────
  Future<List<dynamic>> getNearbyProviders({
    required double latitude, required double longitude,
    double radiusKm = 10, String? serviceTypeId,
  }) async {
    final res = await get('/user/providers/nearby', params: {
      'latitude': latitude, 'longitude': longitude, 'radius_km': radiusKm,
      if (serviceTypeId != null) 'service_type': serviceTypeId,
    });
    final d = res.data;
    if (d is Map && d['providers'] is List) return d['providers'] as List;
    return (d as List?) ?? [];
  }

  // ── Interventions ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getEstimate({
    required String serviceTypeId, required String providerId,
    required double userLat, required double userLng,
  }) async {
    final res = await post('/user/interventions/estimate', data: {
      'service_type_id': serviceTypeId, 'provider_id': providerId,
      'user_latitude': userLat, 'user_longitude': userLng,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createIntervention(Map<String, dynamic> data) async {
    final res = await post('/user/interventions', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getInterventions({int page = 1}) async {
    try {
      final res = await get('/user/interventions', params: {'page': page});
      return (res.data['data'] as List?) ?? [];
    } catch (_) { return []; }
  }

  Future<List<dynamic>> getUserInterventions({int page = 1}) =>
      getInterventions(page: page);

  Future<Map<String, dynamic>> getIntervention(String id) async {
    final res = await get('/user/interventions/$id');
    return res.data as Map<String, dynamic>;
  }

  // AJOUTÉ : aucune méthode n'existait pour soumettre une note — seule
  // getUserReviews() (lecture des avis reçus) était présente.
  Future<Map<String, dynamic>> submitReview({
    required String interventionId,
    required int    rating,
    String?         comment,
  }) async {
    final res = await post('/user/interventions/$interventionId/review', data: {
      'rating':  rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return res.data as Map<String, dynamic>;
  }

  // AJOUTÉ : historique des notifications (cloche sur l'accueil, jusqu'ici
  // jamais branchée à rien).
  Future<List<dynamic>> getNotifications({int page = 1}) async {
    try {
      final res = await get('/user/notifications', params: {'page': page});
      return (res.data['data'] as List?) ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> markNotificationsRead() async {
    try {
      await post('/user/notifications/read-all');
    } catch (_) {}
  }

  Future<void> cancelIntervention(String id, {String? reason}) async {
    try { await post('/user/interventions/$id/cancel', data: {'reason': reason}); }
    catch (_) {}
  }

  Future<void> updateInterventionStatus(String id, String status) async {
    try { await post('/user/interventions/$id/cancel', data: {'reason': status}); }
    catch (_) {}
  }

  // ── Emergency ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> createEmergencyAlert({
    required String type, required double latitude, required double longitude,
    String? address, String? description,
  }) async {
    final res = await post('/user/emergency', data: {
      'type': type, 'latitude': latitude, 'longitude': longitude,
      if (address     != null) 'address':     address,
      if (description != null) 'description': description,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── User ──────────────────────────────────────────────────────────────────

  /// Récupère le profil courant. Tolère deux formes de réponse :
  /// `{ "user": {...} }` ou directement `{...}`.
  Future<Map<String, dynamic>> getMe() async {
    final res = await get('/user/me');
    final d = res.data;
    if (d is Map && d['user'] is Map) {
      return Map<String, dynamic>.from(d['user'] as Map);
    }
    return Map<String, dynamic>.from(d as Map);
  }

  /// Met à jour le profil (nom, whatsapp, …). Les erreurs sont propagées
  /// pour que l'UI puisse les afficher (ne plus masquer un échec backend).
  Future<Map<String, dynamic>> updateUser(Map<String, dynamic> data) async {
    final res = await patch('/user/me', data: data);
    final d = res.data;
    if (d is Map && d['user'] is Map) {
      return Map<String, dynamic>.from(d['user'] as Map);
    }
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// Envoie réellement la photo de profil en multipart (champ `photo`).
  /// Retourne le profil mis à jour renvoyé par le backend.
  Future<Map<String, dynamic>> uploadUserPhoto(String filePath) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: 'profile.jpg'),
    });
    final res = await _dio.post('/user/photo', data: form);
    final d = res.data;
    if (d is Map && d['user'] is Map) {
      return Map<String, dynamic>.from(d['user'] as Map);
    }
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  Future<List<dynamic>> getUserReviews() async {
    try {
      final res = await get('/user/reviews');
      final d = res.data;
      if (d is Map && d['data'] is List) return d['data'] as List;
      return (d as List?) ?? [];
    } catch (_) { return []; }
  }

  // AJOUTÉ : aucune méthode n'existait pour voir les avis que LE CLIENT a
  // lui-même donnés aux prestataires (seuls les avis reçus étaient visibles).
  Future<List<dynamic>> getReviewsGiven() async {
    try {
      final res = await get('/user/reviews/given');
      final d = res.data;
      if (d is Map && d['data'] is List) return d['data'] as List;
      return (d as List?) ?? [];
    } catch (_) { return []; }
  }

  // ── Vehicles ──────────────────────────────────────────────────────────────

  /// Liste les véhicules de l'utilisateur. Tolère `{ "data": [...] }`,
  /// `{ "vehicles": [...] }` ou directement `[...]`.
  Future<List<dynamic>> getVehicles() async {
    final res = await get('/user/vehicles');
    final d = res.data;
    if (d is Map && d['data'] is List) return d['data'] as List;
    if (d is Map && d['vehicles'] is List) return d['vehicles'] as List;
    return (d as List?) ?? [];
  }

  /// Ajoute un véhicule. Les erreurs sont propagées (plus de faux succès).
  Future<Map<String, dynamic>> addVehicle(Map<String, dynamic> data) async {
    final res = await post('/user/vehicles', data: data);
    final d = res.data;
    if (d is Map && d['vehicle'] is Map) {
      return Map<String, dynamic>.from(d['vehicle'] as Map);
    }
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  Future<void> deleteVehicle(String id) async {
    await delete('/user/vehicles/$id');
  }
}
