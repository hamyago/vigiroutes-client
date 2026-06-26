import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/models/service_type_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/service_type_service.dart';

enum RequestStep { selectService, selectProvider, confirm }

enum SubmitError { none, generic }

class RequestController extends ChangeNotifier {
  final _api      = ApiService.instance;
  final _location = LocationService();

  RequestStep           _step          = RequestStep.selectService;
  ServiceTypeModel?     _selectedService;
  ProviderModel?        _selectedProvider;
  Map<String, dynamic>? _estimate;
  String                _paymentMethod = 'cash';
  bool                  _isLoading     = false;
  String?               _error;
  SubmitError           _submitError   = SubmitError.none;
  String?               _createdInterventionId;
  LatLng?               _userPosition;
  String?               _userAddress;

  RequestStep           get step                   => _step;
  ServiceTypeModel?     get selectedService        => _selectedService;
  ProviderModel?        get selectedProvider       => _selectedProvider;
  Map<String, dynamic>? get estimate               => _estimate;
  String                get paymentMethod          => _paymentMethod;
  bool                  get isLoading              => _isLoading;
  String?               get error                  => _error;
  SubmitError           get submitError            => _submitError;
  String?               get createdInterventionId  => _createdInterventionId;
  LatLng?               get userPosition           => _userPosition;
  String?               get userAddress            => _userAddress;

  // Charger depuis l'API au lieu des données statiques
  List<ServiceTypeModel> get services =>
      ServiceTypeService.instance.serviceTypes;

  Future<void> initialize({ProviderModel? preselectedProvider}) async {
    _step        = RequestStep.selectService;
    _submitError = SubmitError.none;
    _error       = null;
    _estimate    = null;

    // Charger les service types si pas encore chargés
    await ServiceTypeService.instance.load();

    final pos = await _location.getCurrentPosition();
    if (pos != null) {
      _userPosition = LatLng(pos.latitude, pos.longitude);
      _userAddress  = await _location.getAddressFromCoords(
          pos.latitude, pos.longitude);
    }
    if (preselectedProvider != null) _selectedProvider = preselectedProvider;
    notifyListeners();
  }

  void selectService(ServiceTypeModel service) {
    _selectedService = service;
    _step = RequestStep.selectProvider;
    notifyListeners();
  }

  Future<void> selectProvider(ProviderModel provider) async {
    _selectedProvider = provider;
    _step = RequestStep.confirm;
    notifyListeners();
    await _loadEstimate();
  }

  Future<void> _loadEstimate() async {
    if (_selectedService == null ||
        _selectedProvider == null ||
        _userPosition == null) return;
    try {
      _estimate = await _api.getEstimate(
        serviceTypeId: _selectedService!.id,
        providerId:    _selectedProvider!.id,
        userLat:       _userPosition!.latitude,
        userLng:       _userPosition!.longitude,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[RequestController] Erreur devis : $e');
    }
  }

  Future<void> refreshEstimate(UserModel? user) async {
    await _loadEstimate();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void goBack() {
    _submitError = SubmitError.none;
    _error       = null;
    if (_step == RequestStep.confirm) {
      _step = RequestStep.selectProvider;
    } else if (_step == RequestStep.selectProvider) {
      _step = RequestStep.selectService;
    }
    notifyListeners();
  }

  Future<bool> submitRequest({required UserModel user}) async {
    if (_selectedService == null ||
        _selectedProvider == null ||
        _userPosition == null) return false;

    _isLoading   = true;
    _error       = null;
    _submitError = SubmitError.none;
    notifyListeners();

    try {
      final data = await _api.createIntervention({
        'service_type_id':   _selectedService!.id,
        'service_type_name': _selectedService!.name,
        'provider_id':       _selectedProvider!.id,
        'user_latitude':     _userPosition!.latitude,
        'user_longitude':    _userPosition!.longitude,
        'user_address':      _userAddress,
        'payment_method':    _paymentMethod,
      });

      _createdInterventionId = data['id'] as String;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _submitError = SubmitError.generic;
      _error       = 'Erreur lors de la création de la demande.';
      _isLoading   = false;
      notifyListeners();
      return false;
    }
  }
}
