// lib/features/ct/controllers/ct_booking_controller.dart
// ─────────────────────────────────────────────────────────────────────────────
// Contrôleur du flow de réservation CT (5 étapes).
//
// ⚠️ CONTRAT BACKEND (validé le 28/09/2026) :
//   - bookingsStore : crée en 'pending_payment', frais calculés côté backend
//   - L'app récupère booking_fee, transport_fee, total_amount depuis l'API
//   - Le paiement réel passe par /ct/bookings/{id}/pay (DigitalPaye)
//   - Les centres sont filtrés par operator_ids quand on vient d'un devis
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models/vehicle_model.dart';
import '../../../core/models/ct_quote_model.dart';
import '../../../core/services/ct_service.dart';

class CtBookingController extends ChangeNotifier {
  bool _disposed = false;

  // ── Step ──────────────────────────────────────────────────────────────────

  int _step = 1;
  int get step => _step;

  void setStep(int s) {
    if (_step == s) return;
    _step = s;
    notifyListeners();
  }

  void goToStep2() {
    setStep(2);
    loadCenters();
  }

  void goToStep3() => setStep(3);
  void goToStep4() => setStep(4);

  void goBack() {
    if (_step == 5) _stopPolling();
    if (_step > 1) setStep(_step - 1);
  }

  // ── Loading / Error ──────────────────────────────────────────────────────

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  // ── BookingHint (depuis acceptation devis) ───────────────────────────────

  CtBookingHint? _bookingHint;
  CtBookingHint? get bookingHint => _bookingHint;

  /// true si ce flow vient de l'acceptation d'un devis CT.
  bool get fromHint => _bookingHint != null;

  /// IDs des opérateurs CT proposés dans le devis.
  List<String> get hintOperatorIds => _bookingHint?.operatorIds ?? const [];

  /// Applique le hint : pré-charge véhicule, transport, montant, puis saute
  /// directement à l'étape 2 (centre + créneau) filtrée par operatorIds.
  Future<void> applyBookingHint(CtBookingHint hint) async {
    _bookingHint = hint;
    _isLoading = true;
    _error = null;

    // Transport imposé par le devis (l'utilisateur ne pourra pas le changer)
    _transportMode = hint.transportMode;

    // Pré-cocher la case clés si le devis impose le mode chauffeur.
    // Ça débloque immédiatement le bouton Continuer à l'étape 3.
    if (hint.transportMode == 'driver') {
      _keyHandoverAccepted = true;
    }

    if (!_disposed) notifyListeners();

    try {
      _vehicles = await CtService.instance.getVehicles();
      final match = _vehicles.where((v) => v.id == hint.vehicleId).firstOrNull;
      if (match != null) {
        _selectedVehicle = match;
      } else if (_vehicles.isNotEmpty) {
        _selectedVehicle = _vehicles.first;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }

    // Passer directement à l'étape 2 (filtre operator_ids appliqué par le backend)
    setStep(2);
    await loadCenters();
  }

  // ── Vehicles ─────────────────────────────────────────────────────────────

  List<VehicleModel> _vehicles = [];
  List<VehicleModel> get vehicles => _vehicles;

  VehicleModel? _selectedVehicle;
  VehicleModel? get selectedVehicle => _selectedVehicle;

  void selectVehicle(VehicleModel v) {
    _selectedVehicle = v;
    notifyListeners();
  }

  Future<void> loadVehicles() async {
    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();
    try {
      _vehicles = await CtService.instance.getVehicles();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── Centers ──────────────────────────────────────────────────────────────

  List<TechnicalCenterModel> _centers = [];
  List<TechnicalCenterModel> get centers => _centers;

  /// ⚡ Depuis le fix backend (28/09/2026), le filtre operator_ids est
  /// appliqué CÔTÉ SERVEUR dans /ct/centers. Plus besoin de filtrer côté
  /// client. La liste reçue est déjà la bonne.
  List<TechnicalCenterModel> get availableCenters => _centers;

  TechnicalCenterModel? _selectedCenter;
  TechnicalCenterModel? get selectedCenter => _selectedCenter;

  /// Sélectionne un centre et charge ses créneaux pour la date courante.
  void selectCenter(TechnicalCenterModel c) {
    _selectedCenter = c;
    _selectedSlot = null;

    // Centrer la map si le centre a des coordonnées
    if (c.latitude != null && c.longitude != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(c.latitude!, c.longitude!), 14),
      );
    }

    notifyListeners();

    // Charger les créneaux pour la date sélectionnée (ou aujourd'hui)
    final date = _selectedDate ?? DateTime.now();
    loadSlots(_fmtDate(date));
  }

  Future<void> loadCenters({String? date, double? lat, double? lng}) async {
    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      // Passer operator_ids au backend si on vient d'un devis.
      final operatorIds = (_bookingHint != null && _bookingHint!.operatorIds.isNotEmpty)
          ? _bookingHint!.operatorIds
          : null;

      _centers = await CtService.instance.getCenters(
        date: date,
        lat: lat,
        lng: lng,
        operatorIds: operatorIds,
      );

      if (!_disposed) {
        _buildMapMarkers();
        _animateToCenters();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── Slots ────────────────────────────────────────────────────────────────

  List<SessionSlotModel> _slots = [];
  List<SessionSlotModel> get slots => _slots;

  SessionSlotModel? _selectedSlot;
  SessionSlotModel? get selectedSlot => _selectedSlot;

  void selectSlot(SessionSlotModel s) {
    _selectedSlot = s;
    notifyListeners();
  }

  Future<void> loadSlots(String date) async {
    if (_selectedCenter == null) return;
    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      _slots = await CtService.instance
          .getAvailableSlots(_selectedCenter!.id, date);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── Date ─────────────────────────────────────────────────────────────────

  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  /// Change la date sélectionnée :
  ///   - recharge les centres (filtre operator_ids conservé)
  ///   - recharge les créneaux du centre déjà sélectionné (si présent)
  void selectDate(DateTime d) {
    _selectedDate = d;
    _selectedSlot = null;
    notifyListeners();

    final dateStr = _fmtDate(d);
    loadCenters(date: dateStr);

    if (_selectedCenter != null) {
      loadSlots(dateStr);
    }
  }

  /// Format YYYY-MM-DD pour l'API.
  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Transport mode ───────────────────────────────────────────────────────

  String _transportMode = 'self';
  String get transportMode => _transportMode;

  /// Si on vient d'un devis, le transport est imposé — non modifiable.
  bool get transportLocked => fromHint;

  void setTransportMode(String v) {
    if (transportLocked) return;
    if (_transportMode == v) return;
    _transportMode = v;
    notifyListeners();
  }

  // ── Key handover ─────────────────────────────────────────────────────────

  bool _keyHandoverAccepted = false;
  bool get keyHandoverAccepted => _keyHandoverAccepted;

  void setKeyHandoverAccepted(bool v) {
    if (_keyHandoverAccepted == v) return;
    _keyHandoverAccepted = v;
    notifyListeners();
  }

  bool get canProceedStep3 =>
      _transportMode != 'driver' || _keyHandoverAccepted;

  // ── Phone ────────────────────────────────────────────────────────────────

  String? _phone;
  String? get phone => _phone;

  void setPhone(String v) {
    final trimmed = v.trim();
    _phone = trimmed.isEmpty ? null : trimmed;
    notifyListeners();
  }

  bool get requiresPhone =>
      _paymentMethod == 'wave' ||
      _paymentMethod == 'orange_money' ||
      _paymentMethod == 'mtn_money';

  // ── Payment method ───────────────────────────────────────────────────────

  String? _paymentMethod;
  String? get paymentMethod => _paymentMethod;

  void setPaymentMethod(String v) {
    _paymentMethod = v;
    if (v == 'card') _phone = null;
    notifyListeners();
  }

  bool get canPay =>
      _paymentMethod != null &&
      (!requiresPhone || (_phone != null && _phone!.length >= 8));

  // ── Fees (calculés par le backend et renvoyés dans le booking) ───────────

  /// Frais de remorquage (prévisualisation).
  double get towFee => 5000;

  /// Frais de chauffeur (prévisualisation).
  double get driverFee => 8000;

  /// Frais du contrôle technique.
  /// Priorité : valeur renvoyée par le backend après création du booking.
  /// Fallback : montant du devis si on vient d'un hint.
  /// Fallback final : 15000 FCFA (valeur par défaut prudente).
  double get bookingFee {
    // PRIORITÉ 1 : devis accepté = contrat, le montant est figé
    if (fromHint && _bookingHint!.amount > 0) {
      return _bookingHint!.amount.toDouble();
    }
    // PRIORITÉ 2 : valeur backend
    if (_activeBooking != null && _activeBooking!.bookingFee > 0) {
      return _activeBooking!.bookingFee;
    }
    return 15000;
  }

  /// Frais de transport.
  /// ⚠️ Si on vient d'un devis accepté, le transport est DÉJÀ INCLUS dans
  /// le montant total du devis → on ne l'affiche pas séparément (0).
  double get transportFee {
    // Devis = tout inclus, pas de frais transport séparé
    if (fromHint) return 0;
    if (_activeBooking != null && _activeBooking!.transportFee > 0) {
      return _activeBooking!.transportFee;
    }
    return switch (_transportMode) {
      'tow'    => towFee,
      'driver' => driverFee,
      _        => 0,
    };
  }

  /// Montant total à payer.
  /// PRIORITÉ 1 : devis accepté (contrat).
  /// PRIORITÉ 2 : valeur backend.
  /// PRIORITÉ 3 : somme calculée localement (prévisualisation).
  double get totalAmount {
    if (fromHint && _bookingHint!.amount > 0) {
      return _bookingHint!.amount.toDouble();
    }
    if (_activeBooking != null && _activeBooking!.totalAmount > 0) {
      return _activeBooking!.totalAmount;
    }
    return bookingFee + transportFee;
  }

  // ── Active booking ───────────────────────────────────────────────────────

  CtBookingModel? _activeBooking;
  CtBookingModel? get activeBooking => _activeBooking;

  bool _paymentConfirmed = false;
  bool get paymentConfirmed => _paymentConfirmed;

  String? _paymentUrl;
  String? get paymentUrl => _paymentUrl;

  String? _qrToken;
  String? get qrToken => _qrToken;

  // ── Countdown ────────────────────────────────────────────────────────────

  int _reservationSecondsLeft = 0;
  int get reservationSecondsLeft => _reservationSecondsLeft;

  Timer? _countdownTimer;

  void _startCountdown() {
    _countdownTimer?.cancel();
    final until = _activeBooking?.slotReservedUntil;
    if (until == null) return;

    _reservationSecondsLeft = until.difference(DateTime.now()).inSeconds;
    if (_reservationSecondsLeft <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _reservationSecondsLeft = until.difference(DateTime.now()).inSeconds;
      if (_reservationSecondsLeft <= 0) {
        _reservationSecondsLeft = 0;
        timer.cancel();
        _stopPolling();
        setStep(1);
      } else {
        if (!_disposed) notifyListeners();
      }
    });
  }

  // ── Polling ──────────────────────────────────────────────────────────────

  Timer? _pollingTimer;
  bool _isPolling = false;
  bool get isPolling => _isPolling;

  void startPolling() {
    if (_activeBooking == null || _isPolling) return;
    _isPolling = true;
    if (!_disposed) notifyListeners();

    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkPaymentStatus();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (_isPolling) {
      _isPolling = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _checkPaymentStatus() async {
    if (_activeBooking == null) return;
    try {
      final booking = await CtService.instance.getBooking(_activeBooking!.id);
      if (booking.paymentStatus == 'paid' || booking.status == 'confirmed') {
        _paymentConfirmed = true;
        _qrToken = booking.qrToken ?? _qrToken;
        _activeBooking = booking;
        _stopPolling();
        if (!_disposed) notifyListeners();
      }
    } catch (_) {
      // Erreur silencieuse — on retente au prochain tick
    }
  }

  // ── Map ──────────────────────────────────────────────────────────────────

  Set<Marker> _mapMarkers = {};
  Set<Marker> get mapMarkers => _mapMarkers;

  GoogleMapController? _mapController;

  void onMapCreated(GoogleMapController c) {
    _mapController = c;
    if (_centers.isNotEmpty) _animateToCenters();
  }

  void _buildMapMarkers() {
    _mapMarkers = _centers
        .where((c) => c.latitude != null && c.longitude != null)
        .map((c) => Marker(
              markerId: MarkerId(c.id),
              position: LatLng(c.latitude!, c.longitude!),
              infoWindow: InfoWindow(title: c.name),
              onTap: () => selectCenter(c),
            ))
        .toSet();
    if (!_disposed) notifyListeners();
  }

  void _animateToCenters() {
    final withCoords = _centers
        .where((c) => c.latitude != null && c.longitude != null)
        .toList();
    if (withCoords.isEmpty || _mapController == null) return;

    if (withCoords.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(withCoords.first.latitude!, withCoords.first.longitude!),
          13,
        ),
      );
      return;
    }

    double minLat = withCoords.first.latitude!;
    double maxLat = withCoords.first.latitude!;
    double minLng = withCoords.first.longitude!;
    double maxLng = withCoords.first.longitude!;

    for (final c in withCoords) {
      if (c.latitude! < minLat) minLat = c.latitude!;
      if (c.latitude! > maxLat) maxLat = c.latitude!;
      if (c.longitude! < minLng) minLng = c.longitude!;
      if (c.longitude! > maxLng) maxLng = c.longitude!;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  // ── API actions ──────────────────────────────────────────────────────────

  /// Crée le booking (status = 'pending_payment' côté backend).
  Future<bool> initiateBooking() async {
    if (_selectedVehicle == null ||
        _selectedCenter == null ||
        _selectedSlot == null) {
      _error = 'Veuillez compléter toutes les sélections.';
      if (!_disposed) notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      _activeBooking = await CtService.instance.initiateBooking(
        vehicleId: _selectedVehicle!.id,
        sessionId: _selectedSlot!.sessionId,
        transportOption: _transportMode,
        quoteId: _bookingHint?.quoteId,
      );
      _startCountdown();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Initie le paiement DigitalPaye.
  /// Retourne true si l'URL de paiement (ou le QR direct) a été obtenu.
  Future<bool> pay() async {
    if (_activeBooking == null || _paymentMethod == null) {
      _error = 'Aucune réservation active ou mode de paiement non sélectionné.';
      if (!_disposed) notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      final result = await CtService.instance.initiatePayment(
        _activeBooking!.id,
        paymentMethod: _paymentMethod!,
        phone: _phone,
      );

      _paymentUrl = result['payment_url'] as String?;
      _qrToken = (result['qr_token'] as String?) ?? _activeBooking!.qrToken;

      // Si le backend renvoie déjà un qr_token (paiement direct confirmé),
      // on peut marquer comme confirmé.
      if (_qrToken != null && result['payment_url'] == null) {
        _paymentConfirmed = true;
      }

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── Regenerate QR ────────────────────────────────────────────────────────

  /// Regénère le QR code d'une réservation expirée.
  ///
  /// Après succès, on **recharge** le booking depuis l'API pour garantir
  /// que `qrToken` et `qrExpiresAt` sont bien à jour (source de vérité serveur).
  ///
  /// Retourne `true` si succès, `false` sinon (avec `_error` rempli).
  Future<bool> regenerateQr() async {
    if (_activeBooking == null) return false;

    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();

    try {
      final result = await CtService.instance.regenerateQr(_activeBooking!.id);

      final newToken = result['qr_token'] as String?;
      if (newToken == null || newToken.isEmpty) {
        _error = 'Token QR manquant dans la réponse serveur';
        return false;
      }

      // Met à jour directement le token en mémoire (rapide, sans reload)
      _qrToken = newToken;

      // Puis recharge le booking complet pour rafraîchir qrExpiresAt
      // et tous les autres champs serveur.
      try {
        final freshBooking = await CtService.instance.getBooking(_activeBooking!.id);
        _activeBooking = freshBooking;
      } catch (_) {
        // Si le reload échoue, on garde au moins le token à jour.
      }

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── Reset ────────────────────────────────────────────────────────────────

  void reset() {
    _countdownTimer?.cancel();
    _stopPolling();

    _step = 1;
    _isLoading = false;
    _error = null;

    _bookingHint = null;

    _vehicles = [];
    _selectedVehicle = null;

    _centers = [];
    _selectedCenter = null;

    _slots = [];
    _selectedSlot = null;
    _selectedDate = null;

    _transportMode = 'self';
    _keyHandoverAccepted = false;

    _phone = null;
    _paymentMethod = null;
    _paymentUrl = null;

    _activeBooking = null;
    _paymentConfirmed = false;
    _qrToken = null;
    _reservationSecondsLeft = 0;

    _mapMarkers = {};

    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    // ⚠️ On ne dispose PAS _mapController ici : c'est le widget GoogleMap
    // qui en est propriétaire. Le disposer ici peut crasher sur iOS.
    super.dispose();
  }
}