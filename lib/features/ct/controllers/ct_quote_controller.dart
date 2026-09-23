import 'package:flutter/material.dart';
import '../../../core/models/ct_quote_model.dart';
import '../../../core/services/ct_quote_service.dart';

class CtQuoteController extends ChangeNotifier {
  final _service = CtQuoteService.instance;

  // ── Liste des demandes ──────────────────────────────────────────────────────
  List<CtQuoteRequestModel> requests = [];
  bool isLoadingList = false;
  String? listError;

  Future<void> loadRequests() async {
    isLoadingList = true;
    listError = null;
    notifyListeners();
    try {
      requests = await _service.getMyRequests();
    } catch (e) {
      listError = 'Impossible de charger les demandes.';
    } finally {
      isLoadingList = false;
      notifyListeners();
    }
  }

  // ── Détail d'une demande ────────────────────────────────────────────────────
  CtQuoteRequestModel? currentRequest;
  bool isLoadingDetail = false;
  String? detailError;

  Future<void> loadRequest(String id) async {
    isLoadingDetail = true;
    detailError = null;
    notifyListeners();
    try {
      currentRequest = await _service.getRequest(id);
    } catch (e) {
      detailError = 'Impossible de charger le devis.';
    } finally {
      isLoadingDetail = false;
      notifyListeners();
    }
  }

  // ── Création d'une demande ──────────────────────────────────────────────────
  bool isSubmitting = false;
  String? submitError;
  CtQuoteRequestModel? createdRequest;

  Future<bool> submitRequest({
    required String vehicleId,
    required String providerId,
    required String transportMode,
    String? notes,
  }) async {
    isSubmitting = true;
    submitError = null;
    notifyListeners();
    try {
      createdRequest = await _service.createRequest(
        vehicleId: vehicleId,
        providerId: providerId,
        transportMode: transportMode,
        notes: notes,
      );
      return true;
    } catch (e) {
      submitError = 'Erreur lors de l\'envoi de la demande.';
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  // ── Répondre à un devis ─────────────────────────────────────────────────────
  bool isResponding = false;
  String? respondError;
  CtBookingHint? bookingHint;

  Future<bool> acceptQuote(String requestId) async => _respond(requestId, 'accepted');
  Future<bool> refuseQuote(String requestId) async => _respond(requestId, 'refused');

  Future<bool> _respond(String requestId, String decision) async {
    isResponding = true;
    respondError = null;
    bookingHint = null;
    notifyListeners();
    try {
      bookingHint = await _service.respond(requestId, decision);
      // Refresh detail
      currentRequest = await _service.getRequest(requestId);
      return true;
    } catch (e) {
      respondError = 'Erreur lors de la réponse.';
      return false;
    } finally {
      isResponding = false;
      notifyListeners();
    }
  }
}
