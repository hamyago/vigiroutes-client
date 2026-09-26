import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/ct_service.dart';

class CtBookingController extends ChangeNotifier {
  // FIX Bug D : drapeau pour eviter notifyListeners() apres dispose()
  // Les methodes async loadCenters() et loadSlots() appelaient notifyListeners()
  // dans leur bloc finally, meme si le widget avait deja ete detruit entre temps,
  // ce qui provoquait un crash "setState() called after dispose()".
  bool _disposed = false;

  // ── Step ──────────────────────────────────────────────────────────────────
  int _step = 1;
  int get step => _step;

  void setStep(int s) {
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
    _selectedSlot = null;
    if (c.latitude != null && c.longitude != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(c.latitude!, c.longitude!), 14),
      );
    }
    notifyListeners();
    if (_selectedDate != null) {
      final dateStr =
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      loadSlots(dateStr);
    } else {
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
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
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

  bool get canProceedStep3 =>
      _transportMode != 'driver' || _keyHandoverAccepted;

  // ── Phone (Wave / Orange Money / MTN) ────────────────────────────────────
  String? _phone;
  String? get phone => _phone;

  void setPhone(String v) {
    _phone = v.trim().isEmpty ? null : v.trim();
    notifyListeners();
  }

  bool get requiresPhone =>
      _paymentMethod == 'wave' ||
      _paymentMethod == 'orange_money' ||
      _paymentMethod == 'mtn_money';

  bool get canPay =>
      _paymentMethod != null &&
      (!requiresPhone || (_phone != null && _phone!.length >= 8));

  // ── Fees ──────────────────────────────────────────────────────────────────
  double get towFee => 5000;
  double get driverFee => 8000;

  double get bookingFee => _activeBooking?.bookingFee ?? 15000;

  double get transportFee =>
      _activeBooking?.transportFee ??
      (_transportMode == 'tow'
          ? towFee
          : _transportMode == 'driver'
              ? driverFee
              : 0);

  double get totalAmount =>
      _activeBooking?.totalAmount ?? (bookingFee + transportFee);

  // ── Payment ───────────────────────────────────────────────────────────────
  String? _paymentMethod;
  String? get paymentMethod => _paymentMethod;

  void setPaymentMethod(String v) {
    _paymentMethod = v;
    if (v == 'card') _phone = null;
    notifyListeners();
  }

  String? _paymentUrl;
  String? get paymentUrl => _paymentUrl;

  String? _qrToken;
  String? get qrToken => _qrToken;

  String? get qrCodeUrl => null;

  // ── Active booking ────────────────────────────────────────────────────────
  CtBookingModel? _activeBooking;
  CtBookingModel? get activeBooking => _activeBooking;

  // ── Payment confirmed (apres polling) ────────────────────────────────────
  bool _paymentConfirmed = false;
  bool get paymentConfirmed => _paymentConfirmed;

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
        _stopPolling();
        setStep(1);
      } else {
        if (!_disposed) notifyListeners();
      }
    });
  }

  // ── Polling ───────────────────────────────────────────────────────────────
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
    _isPolling = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> _checkPaymentStatus() async {
    if (_activeBooking == null) return;
    try {
      final booking =
          await CtService.instance.getBooking(_activeBooking!.id);
      if (booking.paymentStatus == 'paid' ||
          booking.status == 'confirmed') {
        _paymentConfirmed = true;
        _qrToken = booking.qrToken ?? _qrToken;
        _activeBooking = booking;
        _stopPolling();
        if (!_disposed) notifyListeners();
      }
    } catch (_) {
      // Silencieux — on reessaie au prochain tick
    }
  }

  // ── Map ───────────────────────────────────────────────────────────────────
  Set<Marker> _mapMarkers = {};
  Set<Marker> get mapMarkers => _mapMarkers;

  GoogleMapController? _mapController;

  void onMapCreated(GoogleMapController c) {
    _mapController = c;
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

  // ── API calls ─────────────────────────────────────────────────────────────
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

  Future<void> loadCenters({String? date, double? lat, double? lng}) async {
    _isLoading = true;
    _error = null;
    if (!_disposed) notifyListeners();
    try {
      _centers = await CtService.instance.getCenters(
        date: date,
        lat: lat,
        lng: lng,
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

  Future<bool> initiateBooking() async {
    if (_selectedVehicle == null ||
        _selectedCenter == null ||
        _selectedSlot == null) {
      _error = 'Veuillez completer toutes les selections.';
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

  Future<bool> pay() async {
    if (_activeBooking == null || _paymentMethod == null) {
      _error =
          'Aucune reservation active ou mode de paiement non selectionne.';
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
      _qrToken =
          (result['qr_token'] as String?) ?? _activeBooking!.qrToken;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────
  void reset() {
    _countdownTimer?.cancel();
    _stopPolling();
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
    _phone = null;
    _paymentMethod = null;
    _paymentUrl = null;
    _qrToken = null;
    _activeBooking = null;
    _paymentConfirmed = false;
    _reservationSecondsLeft = 0;
    _mapMarkers = {};
    _mapController = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _stopPolling();
    _mapController?.dispose();
    super.dispose();
  }
}
