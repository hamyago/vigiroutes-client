// ignore_for_file: always_specify_types
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

  void goToStep2() => setStep(2);
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
    _selectedSlot = null;
    notifyListeners();
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
    _selectedSlot = null;
    notifyListeners();
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    loadCenters(date: dateStr);
    if (_selectedCenter != null) loadSlots(dateStr);
  }

  // ── Transport mode ────────────────────────────────────────────────────────
  String _transportMode = 'self';
  String get transportMode => _transportMode;

  void setTransportMode(String v) {
    _transportMode = v;
    if (v != 'driver') _keyHandoverAccepted = false;
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

  // ── Fees ──────────────────────────────────────────────────────────────────
  double get towFee => 5000;
  double get driverFee => 8000;

  double get bookingFee => _activeBooking?.bookingFee ?? 15000;
  double get transportFee => _activeBooking?.transportFee ?? 0;
  double get totalAmount => _activeBooking?.totalAmount ?? (bookingFee + transportFee);

  // ── Payment ───────────────────────────────────────────────────────────────
  String? _paymentMethod;
  String? get paymentMethod => _paymentMethod;

  void setPaymentMethod(String v) {
    _paymentMethod = v;
    notifyListeners();
  }

  String? _phone;
  String? get phone => _phone;
  void setPhone(String v) { _phone = v; notifyListeners(); }

  String? _paymentUrl;
  String? get paymentUrl => _paymentUrl;

  String? _qrCodeUrl;
  String? get qrCodeUrl => _qrCodeUrl;

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
  }

  void _buildMapMarkers() {
    final markers = <Marker>{};
    for (final c in _centers) {
      markers.add(Marker(
        markerId: MarkerId(c.id),
        position: LatLng(c.displayLatitude, c.displayLongitude),
        infoWindow: InfoWindow(title: c.name),
        onTap: () => selectCenter(c),
      ));
    }
    _mapMarkers = markers;
    notifyListeners();
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
        vehicleCategory: _selectedVehicle?.category ?? 'VP',
      );
      _buildMapMarkers();
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
      _error = 'Veuillez compléter toutes les sélections.';
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
        slotTime: _selectedSlot!.slotTime,
        vehicleCategory: _selectedVehicle!.category,
        transportMode: _transportMode,
        keyHandoverAccepted: _keyHandoverAccepted,
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
      _error = 'Aucune réservation active ou méthode de paiement non sélectionnée.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await CtService.instance.initiatePayment(
        _activeBooking!.id,
        paymentMethod: _paymentMethod!,
        phone: _phone,
      );
      _paymentUrl = result['payment_url'] as String?;
      _qrCodeUrl = CtService.instance.qrCodeUrl(_activeBooking!.id);
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
    _phone = null;
    _paymentUrl = null;
    _qrCodeUrl = null;
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
