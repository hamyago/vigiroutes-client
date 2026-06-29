import 'package:flutter/foundation.dart';
import '../models/service_type_model.dart';
import 'api_service.dart';

class ServiceTypeService extends ChangeNotifier {
  static final ServiceTypeService instance = ServiceTypeService._();
  ServiceTypeService._();

  List<ServiceTypeModel> _serviceTypes = [];
  bool _isLoading = false;
  String? _error;

  List<ServiceTypeModel> get serviceTypes => _serviceTypes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoaded => _serviceTypes.isNotEmpty;

  Future<void> load({bool force = false}) async {
    if (_serviceTypes.isNotEmpty && !force) return;

    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final res  = await ApiService.instance.get('/service-types');
      final list = (res.data['service_types'] as List)
          .map((e) => ServiceTypeModel.fromJson(e as Map<String, dynamic>))
          .toList();

      _serviceTypes = list;
      _isLoading    = false;
      debugPrint('[ServiceTypes] ${list.length} types chargés');
      notifyListeners();
    } catch (e) {
      debugPrint('[ServiceTypes] Erreur: $e');
      _error     = 'Impossible de charger les services';
      _isLoading = false;
      notifyListeners();
    }
  }

  ServiceTypeModel? findById(String id) =>
      _serviceTypes.where((s) => s.id == id).firstOrNull;

  ServiceTypeModel? findBySlug(String slug) =>
      _serviceTypes.where((s) => s.slug == slug).firstOrNull;
}
