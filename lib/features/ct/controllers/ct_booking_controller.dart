import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/ct_service.dart';

class CtBookingController extends ChangeNotifier {
  // ── Step ──────────────────────────────────────────────────────────────────
  int _step = 1;
  int get step => _step;

  void setStep(int s) {
    _step = s;
    notifyListeners();
  }

  // FIX : charge les centres en même temps que l'on passe à l'étape 2
  void goToStep2() {
    setStep(2);
    loadCenters();
  }

  void goToStep3() => setStep(3);
  void goToStep4() => setStep(4);
  void goBack() => setStep(_step - 1);

  // ── Loading / Error ───────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Vehicles ──────────────────────────────────────────────────────────────
  List<VehicleModel> _vehicles = [];
  List<VehicleModel> get vehicles => _vehicles;

  VehicleModel? _selectedVehicle;
  VehicleModel? get selectedVehicle => _selectedVehicle;

  void selectVehicle(VehicleModel v) {
    _selectedVehicle = v;
    notifyListeners();
  }

  // ── Centers ───────────────────────────────────────────────────────────────
  List<TechnicalCenterModel> _centers = [];
  List<TechnicalCenterModel> get centers => _centers;
  List<TechnicalCenterModel> get availableCenters => _centers;

  TechnicalCenterModel? _selectedCenter;
  TechnicalCenterModel? get selectedCenter => _selectedCenter;

  void selectCenter(TechnicalCenterModel c) {
    _selectedCenter = c;
    _selectedSlot = null; // reset le slot quand on change de centre
    // FIX : déplacer la caméra vers le centre sélectionné
    if (c.latitude != null && c.longitude != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(c.latitude!, c.longitude!), 14),
      );
    }
    notifyListeners();
    // FIX BOUTON CONTINUER : charger les slots pour la date déjà sélectionnée
    // dès qu'on choisit un centre (sans attendre un changement de date).
    if (_selectedDate != null) {
      final dateStr =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      loadSlots(dateStr);
    } else {
      // Pas de date choisie → charger les slots pour aujourd'hui par défaut
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      loadSlots(dateStr);
    }
  }

  // ── Slots ─────────────────────────────────────────────────────────────────
  List<SessionSlotModel> _slots = [];
  List<SessionSlotModel> get slots => _slots;

  SessionSlotModel? _selectedSlot;
  SessionSlotModel? get selectedSlot => _selectedSlot;

  void selectSlot(SessionSlotModel s) {
    _selectedSlot = s;
    notifyListeners();
  }

  // ── Date ──────────────────────────────────────────────────────────────────
  DateTime? _selectedDate;
  DateTime? get selectedDate => _selectedDate;

  void selectDate(DateTime d) {
    _selectedDate = d;
    notifyListeners();
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    loadCenters(date: dateStr);
    loadSlots(dateStr);
  }

  // ── Transport mode ────────────────────────────────────────────────────────
  String _transportMode = 'self';
  String get transportMode => _transportMode;

  void setTransportMode(String v) {
    _transportMode = v;
    notifyListeners();
  }

  // ── Key handover ──────────────────────────────────────────────────────────
  bool _keyHandoverAccepted = false;
  bool get keyHandoverAccepted => _keyHandoverAccepted;

  void setKeyHandoverAccepted(bool v) {
    _keyHandoverAccepted = v;
    notifyListeners();
  }

  bool get canProceedStep3 => _transportMode != 'driver' || _keyHandoverAccepted;

  // ── Fees ──────────────────────────────────────────────────────────────────
  double get towFee => 5000;
  double get driverFee => 8000;

  double get bookingFee =>
      _activeBooking?.bookingFee ?? 15000;

  double get transportFee =>
      _activeBooking?.transportFee ?? (_transportMode == 'tow' ? towFee : _transportMode == 'driver' ? driverFee : 0);

  double get totalAmount =>
      _activeBooking?.totalAmount ?? (bookingFee + transportFee);

  // ── Payment ───────────────────────────────────────────────────────────────
  String? _paymentMethod;
  String? get paymentMethod => _paymentMethod;

  void setPaymentMethod(String v) {
    _paymentMethod = v;
    notifyListeners();
  }

  String? _paymentUrl;
  String? get paymentUrl => _paymentUrl;

  // FIX Bug 2 : on stocke le token QR local (présent dans CtBookingModel)
  // plutôt qu'une URL authentifiée que Image.network ne peut pas charger.
  String? _qrToken;
  String? get qrToken => _qrToken;

  /// Conservé pour rétro-compatibilité dans les écrans qui l'utilisent encore.
  String? get qrCodeUrl => null; // plus utilisé — voir qrToken

  // ── Active booking ────────────────────────────────────────────────────────
  CtBookingModel? _activeBooking;
  CtBookingModel? get activeBooking => _activeBooking;

  // ── Reservation countdown ─────────────────────────────────────────────────
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
        setStep(1);
      } else {
        notifyListeners();
      }
    });
  }

  // ── Map ───────────────────────────────────────────────────────────────────
  Set<Marker> _mapMarkers = {};
  Set<Marker> get mapMarkers => _mapMarkers;

  GoogleMapController? _mapController;

  void onMapCreated(GoogleMapController c) {
    _mapController = c;
    // FIX : si des centres sont déjà chargés quand la carte s'initialise,
    // zoomer immédiatement sur leur barycentre
    if (_centers.isNotEmpty) {
      _animateToCenters();
    }
  }

  void _buildMapMarkers() {
    _mapMarkers = _centers
        .where((c) => c.latitude != null && c.longitude != null)
        .map(
          (c) => Marker(
            markerId: MarkerId(c.id.toString()),
            position: LatLng(c.latitude!, c.longitude!),
            infoWindow: InfoWindow(title: c.name),
            onTap: () => selectCenter(c),
          ),
        )
        .toSet();
    notifyListeners();
  }

  /// Anime la caméra pour afficher tous les centres chargés.
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

    // Calculer le LatLngBounds englobant tous les centres
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
        60, // padding in pixels
      ),
    );
  }

  // ── API calls ─────────────────────────────────────────────────────────────
  Future<void> loadVehicles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _vehicles = await CtService.instance.getVehicles();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCenters({String? date, double? lat, double? lng}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _centers = await CtService.instance.getCenters(
        date: date,
        lat: lat,
        lng: lng,
      );
      _buildMapMarkers();
      // FIX : déplacer la caméra vers les centres chargés
      _animateToCenters();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSlots(String date) async {
    if (_selectedCenter == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _slots = await CtService.instance.getAvailableSlots(_selectedCenter!.id, date);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> initiateBooking() async {
    if (_selectedVehicle == null ||
        _selectedCenter == null ||
        _selectedSlot == null) {
      _error = 'Please complete all selections.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _activeBooking = await CtService.instance.initiateBooking(
        vehicleId: _selectedVehicle!.id,
        sessionId: _selectedSlot!.sessionId,
        transportOption: _transportMode,
      );
      _startCountdown();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> pay() async {
    if (_activeBooking == null || _paymentMethod == null) {
      _error = 'Aucune réservation active ou mode de paiement non sélectionné.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // FIX Bug 2a : on passe maintenant payment_method dans le body.
      final result = await CtService.instance.initiatePayment(
        _activeBooking!.id,
        paymentMethod: _paymentMethod!,
      );
      _paymentUrl = result['payment_url'] as String?;

      // FIX Bug 2b : on utilise le qrToken du booking (déjà dans le modèle)
      // pour générer le QR localement avec qr_flutter — pas besoin d'URL auth.
      // Le backend peut aussi renvoyer un token dans la réponse de pay().
      _qrToken = (result['qr_token'] as String?) ?? _activeBooking!.qrToken;

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  void reset() {
    _countdownTimer?.cancel();
    _step = 1;
    _isLoading = false;
    _error = null;
    _vehicles = [];
    _selectedVehicle = null;
    _centers = [];
    _selectedCenter = null;
    _slots = [];
    _selectedSlot = null;
    _selectedDate = null;
    _transportMode = 'self';
    _keyHandoverAccepted = false;
    _paymentMethod = null;
    _paymentUrl = null;
    _qrToken = null;
    _activeBooking = null;
    _reservationSecondsLeft = 0;
    _mapMarkers = {};
    _mapController = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
