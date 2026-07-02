import 'package:firebase_crashlytics/firebase_crashlytics.dart';
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
    notifyListeners();

    try {
      FirebaseCrashlytics.instance.log('[RequestController] initialize: debut');

      // Charger les service types si pas encore chargés (avec filet de
      // sécurité : ne doit jamais bloquer l'écran indéfiniment).
      await ServiceTypeService.instance
          .load()
          .timeout(const Duration(seconds: 30), onTimeout: () {
        debugPrint('[RequestController] ServiceTypeService.load() timeout');
        FirebaseCrashlytics.instance.log('[RequestController] ServiceTypeService.load() TIMEOUT 30s');
      });
      FirebaseCrashlytics.instance.log('[RequestController] initialize: ServiceTypeService.load() ok');

      final pos = await _location.getCurrentPosition();
      FirebaseCrashlytics.instance.log('[RequestController] initialize: getCurrentPosition() ok (pos=${pos != null})');
      if (pos != null) {
        _userPosition = LatLng(pos.latitude, pos.longitude);
        _userAddress  = await _location.getAddressFromCoords(
            pos.latitude, pos.longitude);
      }
      FirebaseCrashlytics.instance.log('[RequestController] initialize: fin (avant notifyListeners)');

      // Le prestataire est déjà choisi (ex: clic sur sa carte depuis la
      // carte/liste d'accueil) ; il reste à choisir le SERVICE souhaité —
      // voir selectService() qui saute alors directement à la confirmation
      // au lieu de redemander de choisir un prestataire.
      if (preselectedProvider != null) _selectedProvider = preselectedProvider;

      notifyListeners();
    } catch (e) {
      debugPrint('[RequestController] initialize error: $e');
      FirebaseCrashlytics.instance.log('[RequestController] initialize EXCEPTION: $e');
      _error = 'Impossible de charger les informations. Réessayez.';
      notifyListeners();
    }
  }

  void selectService(ServiceTypeModel service) {
    _selectedService = service;
    if (_selectedProvider != null) {
      // Prestataire déjà choisi (préselection) : on saute directement à la
      // confirmation au lieu de redemander de choisir un prestataire.
      _step = RequestStep.confirm;
      notifyListeners();
      _loadEstimate();
    } else {
      _step = RequestStep.selectProvider;
      notifyListeners();
    }
  }

  Future<void> selectProvider(ProviderModel provider) async {
    _selectedProvider = provider;
    _step = RequestStep.confirm;
    notifyListeners();
    await _loadEstimate();
  }

  bool _estimateLoading = false;
  bool get estimateLoading => _estimateLoading;

  Future<void> _loadEstimate() async {
    if (_selectedService == null ||
        _selectedProvider == null ||
        _userPosition == null) return;
    _estimateLoading = true;
    _error           = null;
    notifyListeners();
    FirebaseCrashlytics.instance.log('[RequestController] _loadEstimate: appel API getEstimate');
    try {
      _estimate = await _api.getEstimate(
        serviceTypeId: _selectedService!.id,
        providerId:    _selectedProvider!.id,
        userLat:       _userPosition!.latitude,
        userLng:       _userPosition!.longitude,
      ).timeout(const Duration(seconds: 30));
      _estimateLoading = false;
      FirebaseCrashlytics.instance.log('[RequestController] _loadEstimate: succes');
      notifyListeners();
    } catch (e) {
      debugPrint('[RequestController] Erreur devis : $e');
      FirebaseCrashlytics.instance.log('[RequestController] _loadEstimate EXCEPTION: $e');
      _estimateLoading = false;
      _error = 'Impossible de calculer le devis. Réessayez.';
      notifyListeners();
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
      }).timeout(const Duration(seconds: 30));

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
