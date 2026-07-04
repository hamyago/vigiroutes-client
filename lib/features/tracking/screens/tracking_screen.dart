import '../../../core/services/realtime_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/price_calculator.dart';
import '../../auth/controllers/auth_controller.dart';
import '../widgets/safety_share_sheet.dart';

class TrackingScreen extends StatefulWidget {
  final String interventionId;
  const TrackingScreen({super.key, required this.interventionId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _db = ApiService.instance;
  GoogleMapController? _mapCtrl;
  InterventionModel? _intervention;
  StreamSubscription? _sub;
  Timer? _pollTimer;
  bool _loadError = false;
  // NOUVEAU : évite de réafficher la popup du montant final à chaque
  // sondage/mise à jour une fois qu'elle a déjà été montrée une fois.
  bool _amountPopupShown = false;

  @override
  void initState() {
    super.initState();

    // BUG CORRIGÉ : cet écran ne dépendait QUE du WebSocket pour remplir
    // _intervention, qui ne pousse que les CHANGEMENTS futurs (pas
    // d'instantané initial à l'abonnement — comportement normal de
    // Reverb/Pusher). Juste après la création d'une demande, tant que le
    // prestataire n'a rien accepté, il n'y a rien à recevoir : le spinner
    // restait bloqué indéfiniment. On charge maintenant l'état initial via
    // l'API REST, puis le WebSocket prend le relais pour le temps réel.
    _loadInitial();
    _startPolling();

    // BUG CORRIGÉ : passait widget.interventionId (l'ID de l'intervention)
    // alors que subscribeToIntervention() attend l'ID de l'UTILISATEUR pour
    // construire le canal 'private-user.{userId}'. Le canal résultant ne
    // correspondait jamais à l'utilisateur réel -> l'authentification du
    // canal privé échouait systématiquement (routes/channels.php compare
    // $user->id à cet identifiant) -> aucune mise à jour temps réel n'a
    // jamais pu arriver sur cet écran.
    final userId = context.read<AuthController>().user?.id ?? '';
    _sub = RealtimeService.instance
        .subscribeToIntervention(userId).listen((data) {
      // BUG CORRIGÉ : le payload WebSocket ne contient qu'un SOUS-ENSEMBLE
      // des champs (id, status, position...), pas l'intervention complète.
      // InterventionModel.fromJson() exige des champs obligatoires absents
      // de ce payload partiel (ex: user_id) -> plantait à chaque mise à
      // jour temps réel. On fusionne maintenant avec l'état déjà chargé via
      // copyWithWs, comme déjà fait côté app Pro.
      final incomingId = data['id'] as String?;
      if (incomingId != widget.interventionId) return;
      setState(() {
        _intervention = _intervention?.copyWithWs(data);
      });
      _maybeShowAmountPopup();
      final i = _intervention;
      if (i != null &&
          i.providerLatitude != null &&
          i.providerLongitude != null) {
        _mapCtrl?.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(i.providerLatitude!, i.providerLongitude!),
          ),
        );
      }
    });
  }

  // NOUVEAU : dès que l'intervention passe à 'completed', affiche une
  // popup non bloquante avec le montant final saisi par le prestataire
  // (aucune confirmation requise de la part du client — juste informatif).
  void _maybeShowAmountPopup() {
    final i = _intervention;
    if (i == null || _amountPopupShown) return;
    if (i.status != 'completed') return;

    _amountPopupShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('🎉 Intervention terminée !'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Montant à payer au prestataire :'),
              const SizedBox(height: 8),
              Text(
                PriceCalculator.formatFcfa(i.totalPrice),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.push('/user/review/${i.id}');
              },
              child: const Text('Noter le prestataire'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _loadInitial() async {
    try {
      final data = await _db
          .getIntervention(widget.interventionId)
          .timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() => _intervention = InterventionModel.fromJson(data));
        _maybeShowAmountPopup();
      }
    } catch (e) {
      debugPrint('[TrackingScreen] Erreur chargement initial : $e');
      if (mounted) setState(() => _loadError = true);
    }
  }

  // ── Rafraîchissement automatique par sondage (secours) ──────────────────
  // AJOUTÉ : la fiabilité du WebSocket pour voir le prestataire approcher
  // en temps réel n'a pas pu être confirmée en conditions réelles malgré
  // plusieurs corrections successives côté auth de canal. Ce sondage
  // toutes les 4s repose uniquement sur l'API REST (dont le bon
  // fonctionnement est déjà avéré) — garantie de secours simple et fiable,
  // tourne en plus du WebSocket sans le remplacer.
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final status = _intervention?.status;
      if (status == 'completed' || status == 'cancelled') {
        _pollTimer?.cancel();
        return;
      }
      try {
        final data = await _db
            .getIntervention(widget.interventionId)
            .timeout(const Duration(seconds: 15));
        if (!mounted) return;
        final updated = InterventionModel.fromJson(data);
        setState(() => _intervention = updated);
        _maybeShowAmountPopup();
        if (updated.providerLatitude != null &&
            updated.providerLongitude != null) {
          _mapCtrl?.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(updated.providerLatitude!, updated.providerLongitude!),
            ),
          );
        }
      } catch (e) {
        debugPrint('[TrackingScreen] Erreur sondage : $e');
        // Silencieux : le prochain sondage (4s plus tard) réessaiera.
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pollTimer?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    if (_intervention == null) return markers;

    markers.add(Marker(
      markerId: const MarkerId('user'),
      position: LatLng(
        _intervention!.userLatitude,
        _intervention!.userLongitude,
      ),
      infoWindow: const InfoWindow(title: 'Votre position'),
    ));

    if (_intervention!.providerLatitude != null &&
        _intervention!.providerLongitude != null) {
      markers.add(Marker(
        markerId: const MarkerId('provider'),
        position: LatLng(
          _intervention!.providerLatitude!,
          _intervention!.providerLongitude!,
        ),
        infoWindow: InfoWindow(
          title: _intervention!.providerName ?? 'Prestataire',
        ),
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final i = _intervention;
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: i != null
                  ? LatLng(i.userLatitude, i.userLongitude)
                  : const LatLng(5.3599517, -4.0082563), // Abidjan
              zoom: 14,
            ),
            onMapCreated: (c) => _mapCtrl = c,
            markers: _markers,
            zoomControlsEnabled: false,
            myLocationEnabled: false,
          ),

          // Top bar : bouton retour + bouton sécurité
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Retour
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      onPressed: () => context.go('/user/home'),
                    ),
                  ),

                  // Bouton sécurité (visible dès qu'une intervention est active)
                  if (_intervention != null && _intervention!.isActive)
                    GestureDetector(
                      onTap: () => SafetyShareSheet.show(
                        context,
                        intervention: _intervention!,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🛡️', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 6),
                            Text(
                              'Alerter un proche',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom info panel
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: i == null
                  ? (_loadError
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 40),
                            const SizedBox(height: 8),
                            const Text(
                              'Impossible de charger le suivi de la demande.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() => _loadError = false);
                                _loadInitial();
                              },
                              child: const Text('Réessayer'),
                            ),
                          ],
                        )
                      : const Center(child: CircularProgressIndicator()))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status badge
                        _StatusBadge(status: i.status),
                        const SizedBox(height: 16),

                        // Provider info
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primaryLight,
                              child: Text('👨‍🔧', style: TextStyle(fontSize: 22)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    i.providerName ?? 'En attente...',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    '${i.serviceTypeName} — ${PriceCalculator.formatFcfa(i.totalPrice)}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (i.providerPhone != null)
                              Row(
                                children: [
                                  _ActionBtn(
                                    icon: Icons.phone,
                                    color: AppColors.success,
                                    onTap: () => launchUrl(
                                      Uri.parse('tel:${i.providerPhone}'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _ActionBtn(
                                    icon: Icons.chat,
                                    color: AppColors.primary,
                                    onTap: () => launchUrl(
                                      Uri.parse(
                                        'https://wa.me/${i.providerPhone?.replaceAll('+', '')}',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),

                        if (i.isActive) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Bouton partage sécurité
                              TextButton.icon(
                                onPressed: () => SafetyShareSheet.show(
                                  context,
                                  intervention: i,
                                ),
                                icon: const Text('🛡️',
                                    style: TextStyle(fontSize: 15)),
                                label: const Text(
                                  'Alerter un proche',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              // Séparateur vertical
                              Container(
                                height: 20,
                                width: 1,
                                color: AppColors.border,
                              ),
                              // Bouton annulation
                              TextButton.icon(
                                onPressed: () =>
                                    _showCancelDialog(context, i.id),
                                icon: const Icon(Icons.cancel_outlined,
                                    color: AppColors.error, size: 16),
                                label: const Text(
                                  'Annuler',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (i.isCompleted) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                context.push('/user/review/${i.id}'),
                            child: const Text('Noter le prestataire'),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler l\'intervention ?'),
        content: const Text(
            'Cette action est irréversible. Des frais d\'annulation peuvent s\'appliquer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () async {
              await _db.updateInterventionStatus(
                  id, AppConstants.statusCancelled);
              if (mounted) {
                Navigator.pop(context);
                // ignore: use_build_context_synchronously
                context.go('/user/home');
              }
            },
            child: const Text('Oui, annuler',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'pending' => ('En attente d\'acceptation', AppColors.warning, '⏳'),
      // 'dispatching' : le backend a envoye la demande a un prestataire
      // precis et attend sa reponse (ajoute suite au correctif du dispatch
      // direct — ce statut n'existait pas cote client avant, d'ou l'affichage
      // "? Inconnu" observe juste apres qu'un client ait lance une demande).
      'dispatching' => ('Envoyée au prestataire...', AppColors.warning, '📨'),
      'accepted' => ('Prestataire en route', AppColors.primary, '🚗'),
      'in_progress' => ('Intervention en cours', AppColors.success, '🔧'),
      'completed' => ('Terminée', AppColors.success, '✅'),
      'cancelled' => ('Annulée', AppColors.error, '❌'),
      _ => ('Inconnu', AppColors.textMuted, '❓'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      );
}
