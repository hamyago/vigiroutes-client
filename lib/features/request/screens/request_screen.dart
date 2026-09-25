import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/request_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/models/service_type_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/service_type_service.dart';
import '../../../core/utils/price_calculator.dart';
import '../../../shared/widgets/custom_button.dart';

// Conversion tolérante : Laravel sérialise parfois les colonnes DECIMAL
// (base_price, km_cost, total_price...) sous forme de CHAÎNES dans le JSON
// plutôt que de nombres. Un cast direct `as num` plante dans ce cas
// (« type 'String' is not a subtype of type 'num?' »). Même pattern que
// _toDouble dans core/models/models.dart, dupliqué ici car privé au fichier.
double _estimateNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class RequestScreen extends StatefulWidget {
  final ProviderModel? preselectedProvider;
  final RequestMode mode;
  const RequestScreen({
    super.key,
    this.preselectedProvider,
    this.mode = RequestMode.manual,
  });

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  Timer? _watchdog;
  bool  _postFrameFired = false;
  bool  _initializeDone = false;

  // ── Attente prestataire après soumission ──────────────────────────────────
  // Quand submitRequest() réussit en mode auto, on affiche un écran "Recherche
  // en cours…".
  //
  // FIX Bug A : 3 cas de sortie de la phase de recherche :
  //   1. Timeout 60s sans réponse → popup "indisponible"
  //   2. FCM intervention_update avec statut accepted/dispatched → navigation
  //      vers /user/tracking (gérée par NotificationRouterService)
  //      + _cancelSearch() pour nettoyer l'état local
  //   3. FCM no_provider → _cancelSearch() + popup "indisponible"
  //
  // Le NotificationRouterService navigue vers /user/tracking quand il reçoit
  // intervention_update. Ce faisant, RequestScreen est toujours dans la pile.
  // Sans _cancelSearch(), si l'utilisateur revient en arrière il verrait
  // encore l'écran de recherche (état incohérent).
  bool   _isSearching      = false;
  Timer? _searchTimeoutTimer;
  String? _searchingInterventionId;

  // FIX Bug A : écouter les FCM foreground pendant la recherche
  StreamSubscription<RemoteMessage>? _fcmSubscription;

  void _startSearchTimeout(String interventionId) {
    _searchingInterventionId = interventionId;
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = Timer(const Duration(seconds: 60), () {
      if (!mounted || !_isSearching) return;
      setState(() { _isSearching = false; });
      _showNoProviderDialog();
    });
    setState(() { _isSearching = true; });

    // FIX Bug A : écouter les messages FCM foreground pour reagir en temps réel
    _fcmSubscription?.cancel();
    _fcmSubscription = FirebaseMessaging.onMessage.listen(_onFcmDuringSearch);
  }

  // FIX Bug A : réaction FCM pendant la phase de recherche
  void _onFcmDuringSearch(RemoteMessage message) {
    if (!mounted || !_isSearching) return;
    final type = message.data['type'] as String?;
    final id   = message.data['intervention_id'] as String?;

    // Vérifier que le message concerne NOTRE intervention en cours
    final isOurIntervention = id == null || id == _searchingInterventionId;
    if (!isOurIntervention) return;

    if (type == 'no_provider') {
      // Aucun prestataire disponible — sortir de la recherche
      _cancelSearch();
      _showNoProviderDialog();
    } else if (type == 'intervention_update') {
      final status = message.data['status'] as String?;
      if (status == 'accepted' || status == 'dispatched' || status == 'en_route') {
        // Un prestataire a accepté — NotificationRouterService navigue déjà
        // vers /user/tracking. On nettoie juste l'état local.
        _cancelSearch();
        // Navigation vers tracking si elle n'a pas encore eu lieu
        if (id != null && mounted) {
          context.push('/user/tracking/$id');
        }
      } else if (status == 'cancelled' || status == 'rejected' || status == 'failed') {
        // La demande a été annulée/rejetée
        _cancelSearch();
        _showNoProviderDialog(
          title: 'Demande annulée',
          message: 'La demande a été annulée. Veuillez réessayer.',
        );
      }
    }
  }

  void _cancelSearch() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = null;
    _searchingInterventionId = null;
    _fcmSubscription?.cancel(); // FIX Bug A : arrêter l'écoute FCM
    _fcmSubscription = null;
    if (mounted) setState(() { _isSearching = false; });
  }

  Future<void> _showNoProviderDialog({
    String title   = 'Prestataires indisponibles',
    String message = 'Aucun prestataire n\'est disponible dans votre zone pour le moment.\n\n'
                     'Réessayez dans quelques minutes ou modifiez votre demande.',
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(ctx).pop(); },
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<RequestController>().goBack();
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    FirebaseCrashlytics.instance.log(
        'RequestScreen.initState provider=${widget.preselectedProvider?.id ?? "aucun"}');

    // Watchdog : si rien ne s'est passé après 20s (ni position, ni erreur,
    // ni même le postFrame déclenché), on force un rapport Crashlytics
    // non-fatal avec tout le contexte utile — pour diagnostiquer un
    // blocage à distance, sans câble ni flutter run.
    _watchdog = Timer(const Duration(seconds: 20), _reportIfStuck);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _postFrameFired = true;
      FirebaseCrashlytics.instance.log('RequestScreen: appel ctrl.initialize()');
      await context.read<RequestController>().initialize(
            preselectedProvider: widget.preselectedProvider,
            mode: widget.mode,
          );
      _initializeDone = true;
      FirebaseCrashlytics.instance.log('RequestScreen: ctrl.initialize() terminé');
      _watchdog?.cancel();
    });
  }

  void _reportIfStuck() {
    if (!mounted) return;
    final ctrl = context.read<RequestController>();

    final String reason;
    if (!_postFrameFired) {
      reason = 'addPostFrameCallback jamais déclenché (le widget n\'a peut-être '
          'jamais fini de se construire)';
    } else if (!_initializeDone) {
      reason = 'ctrl.initialize() appelé mais jamais terminé après 20s '
          '(bloqué dans ServiceTypeService.load, getCurrentPosition, ou ailleurs '
          'malgré les timeouts internes)';
    } else if (ctrl.userPosition == null && ctrl.error == null) {
      reason = 'initialize() terminé mais userPosition et error restent null';
    } else {
      return; // Tout va bien, rien à signaler.
    }

    FirebaseCrashlytics.instance.recordError(
      Exception('RequestScreen bloqué 20s+ : $reason'),
      StackTrace.current,
      fatal: false,
      information: [
        'preselectedProvider: ${widget.preselectedProvider?.id ?? "aucun"} '
            '(${widget.preselectedProvider?.name ?? ""})',
        'postFrameFired: $_postFrameFired',
        'initializeDone: $_initializeDone',
        'step: ${ctrl.step}',
        'userPosition: ${ctrl.userPosition}',
        'error: ${ctrl.error}',
        'selectedService: ${ctrl.selectedService?.id}',
        'selectedProvider: ${ctrl.selectedProvider?.id}',
        'estimateLoading: ${ctrl.estimateLoading}',
      ],
    );
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _searchTimeoutTimer?.cancel();
    _fcmSubscription?.cancel(); // FIX Bug A
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RequestController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitle(ctrl.step)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (_isSearching) {
              // FIX Bug A : annuler la recherche si on appuie sur retour
              _cancelSearch();
              return;
            }
            if (ctrl.step == RequestStep.selectService) {
              context.pop();
            } else {
              ctrl.goBack();
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _StepIndicator(step: ctrl.step),
        ),
      ),
      body: _isSearching
          ? _SearchingProviderView(onCancel: _cancelSearch)
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (ctrl.step) {
                RequestStep.selectService  => _SelectServiceStep(ctrl: ctrl),
                RequestStep.selectProvider => _SelectProviderStep(ctrl: ctrl),
                RequestStep.confirm        => _ConfirmStep(
                    ctrl: ctrl,
                    onSubmitted: _startSearchTimeout,
                  ),
              },
            ),
    );
  }

  String _stepTitle(RequestStep step) => switch (step) {
        RequestStep.selectService  => 'Type de service',
        RequestStep.selectProvider => 'Choisir un prestataire',
        RequestStep.confirm        => 'Confirmer la demande',
      };
}

// ── Step 1: Select Service ────────────────────────────────────────────────────

class _SelectServiceStep extends StatelessWidget {
  final RequestController ctrl;
  const _SelectServiceStep({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final stService = ServiceTypeService.instance;

    if (stService.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stService.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(stService.error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => stService.load(force: true),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final all = stService.serviceTypes;
    // Si un prestataire est présélectionné (tapé sur la carte), on ne
    // propose QUE ses propres services, pas tout le catalogue.
    final prov = ctrl.selectedProvider;
    final services = (prov != null && prov.serviceTypes.isNotEmpty)
        ? all
            .where((s) =>
                prov.serviceTypes.contains(s.slug) ||
                prov.serviceTypes.contains(s.id))
            .toList()
        : all;

    if (services.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "Ce prestataire n'a pas encore renseigné ses services.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: services.length,
      itemBuilder: (_, i) => _ServiceTile(
        service: services[i],
        onTap: () => ctrl.selectService(services[i]),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final ServiceTypeModel service;
  final VoidCallback onTap;
  const _ServiceTile({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: service.colorValue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(service.emoji,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                service.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'à partir de ${service.formattedBasePrice}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Step 2: Select Provider ───────────────────────────────────────────────────

class _SelectProviderStep extends StatefulWidget {
  final RequestController ctrl;
  const _SelectProviderStep({required this.ctrl});

  @override
  State<_SelectProviderStep> createState() => _SelectProviderStepState();
}

class _SelectProviderStepState extends State<_SelectProviderStep> {
  List<ProviderModel> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  bool _noPosition = false;

  Future<void> _loadProviders() async {
    final pos       = widget.ctrl.userPosition;
    final serviceId = widget.ctrl.selectedService?.id;
    if (pos == null) {
      // BUG CORRIGÉ : avant, un simple `return` laissait _loading=true pour
      // toujours (spinner infini, silencieux, sans erreur ni exception —
      // donc invisible pour Crashlytics). Cas réel : GPS désactivé,
      // permission refusée, ou position jamais obtenue lors de
      // l'initialisation, mais l'utilisateur a quand même pu avancer
      // jusqu'à cet écran.
      FirebaseCrashlytics.instance.recordError(
        Exception('_SelectProviderStep: userPosition null, impossible de charger les prestataires'),
        StackTrace.current,
        fatal: false,
      );
      if (mounted) {
        setState(() {
          _loading     = false;
          _noPosition  = true;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loading    = true;
        _noPosition = false;
      });
    }
    try {
      final data = await ApiService.instance.getNearbyProviders(
        latitude:      pos.latitude,
        longitude:     pos.longitude,
        serviceTypeId: serviceId,
      ).timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          _providers = data
              .map((e) => ProviderModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      FirebaseCrashlytics.instance.log('[_SelectProviderStep] getNearbyProviders erreur: $e');
      if (mounted) { setState(() => _loading = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.ctrl.selectedService;

    if (_noPosition) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Position GPS indisponible.\nActivez le GPS et réessayez.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProviders,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_providers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                service != null
                    ? 'Aucun prestataire disponible pour "${service.name}" près de vous.'
                    : 'Aucun prestataire disponible près de vous.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProviders,
                child: const Text('Actualiser'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _providers.length,
      itemBuilder: (_, i) {
        final p = _providers[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.distanceKm != null)
                  Text('📍 ${p.distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 12)),
                Row(children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(p.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12)),
                ]),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.ctrl.selectProvider(p),
          ),
        );
      },
    );
  }
}

// ── Step 3: Confirm ───────────────────────────────────────────────────────────

class _ConfirmStep extends StatelessWidget {
  final RequestController ctrl;
  final void Function(String interventionId)? onSubmitted;
  const _ConfirmStep({required this.ctrl, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Récap ──────────────────────────────────────────────────────
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Récapitulatif',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  _Row('Service', ctrl.selectedService?.name ?? '—'),
                  if (ctrl.selectedProvider != null)
                    _Row('Prestataire', ctrl.selectedProvider!.name),
                  if (ctrl.isAuto)
                    const _Row('Affectation', 'Automatique'),
                  _Row('Position', ctrl.userAddress ?? 'Position GPS'),
                  _Row('Paiement', _paymentLabel(ctrl.paymentMethod)),
                  if (ctrl.estimateLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    )
                  else if (ctrl.estimate != null) ...[
                    const Divider(height: 20),
                    if (_estimateNum(ctrl.estimate!['distance_km']) > 0)
                      _Row('Distance',
                          '${_estimateNum(ctrl.estimate!['distance_km']).toStringAsFixed(1)} km'),
                    _Row('Prix de base',
                        _fmt(_estimateNum(ctrl.estimate!['base_price']))),
                    if (_estimateNum(ctrl.estimate!['km_cost']) > 0)
                      _Row('Déplacement',
                          _fmt(_estimateNum(ctrl.estimate!['km_cost']))),
                    _Row(
                      'Total estimé',
                      _fmt(_estimateNum(ctrl.estimate!['total_price'])),
                      bold: true,
                      valueColor: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Paiement ───────────────────────────────────────────────────
          const Text('Mode de paiement',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          _PaymentMethods(
            selected: ctrl.paymentMethod,
            onSelect: ctrl.setPaymentMethod,
          ),
          const SizedBox(height: 16),

          if (ctrl.submitError == SubmitError.generic) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(ctrl.error!,
                  style: const TextStyle(color: AppColors.error)),
            ),
          ],

          const SizedBox(height: 32),
          AppButton(
            label: 'Envoyer la demande',
            isLoading: ctrl.isLoading,
            enabled: true,
            icon: Icons.sos,
            onPressed: () async {
              if (auth.user == null) return;
              final ok = await ctrl.submitRequest(user: auth.user!);
              if (!ok || !context.mounted) return;

              final interventionId = ctrl.createdInterventionId;
              if (interventionId == null) return;

              if (ctrl.isAuto) {
                // Mode auto : on ne navigue PAS vers tracking tout de suite.
                // On attend 60s que le serveur dispatche et qu'un prestataire
                // accepte (→ FCM intervention_update naviguera vers /user/tracking).
                // Si personne ne répond en 60s → popup "indisponible".
                // FIX Bug A : le FCM no_provider/intervention_update est aussi écouté.
                onSubmitted?.call(interventionId);
              } else {
                // Mode manuel : le prestataire est déjà ciblé, on va au tracking.
                context.go('/user/tracking/$interventionId');
              }
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              ctrl.isAuto
                  ? 'Nous contactons le meilleur prestataire disponible près de vous. Le déplacement sera ajouté une fois le prestataire trouvé.'
                  : 'Le prestataire sera notifié immédiatement.',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => '${v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]} ',
      )} FCFA';

  String _paymentLabel(String method) => switch (method) {
        'cash'         => 'Espèces',
        'orange_money' => 'Orange Money',
        'wave'         => 'Wave',
        _              => method,
      };
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? valueColor;
  const _Row(this.label, this.value,
      {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary,
                fontSize: bold ? 16 : 14,
              )),
        ]),
      );
}

class _PaymentMethods extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  const _PaymentMethods(
      {required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final methods = [
      ('cash',         '💵 Espèces'),
      ('orange_money', '🟠 Orange Money'),
      ('wave',         '🔵 Wave'),
    ];
    return Column(
      children: methods
          .map<Widget>((m) => ListTile(
                leading: Radio<String>(
                  value: m.$1,
                  groupValue: selected,
                  activeColor: AppColors.primary,
                  onChanged: (v) { if (v != null) onSelect(v); },
                ),
                title: Text(m.$2),
                onTap: () => onSelect(m.$1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ))
          .toList(),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final RequestStep step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
        value: (step.index + 1) / 3,
        backgroundColor: AppColors.border,
        valueColor:
            const AlwaysStoppedAnimation<Color>(AppColors.primary),
        minHeight: 4,
      );
}

// ── Vue "Recherche prestataire en cours" ─────────────────────────────────────
// Affichée après soumission en mode AUTO pendant max 60 secondes.
// FIX Bug A : aussi réactif aux FCM intervention_update et no_provider.
class _SearchingProviderView extends StatefulWidget {
  final VoidCallback onCancel;
  const _SearchingProviderView({required this.onCancel});

  @override
  State<_SearchingProviderView> createState() => _SearchingProviderViewState();
}

class _SearchingProviderViewState extends State<_SearchingProviderView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _dots = 0;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() { _dots = (_dots + 1) % 4; });
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dots;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône animée
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Opacity(
              opacity: 0.5 + 0.5 * _pulse.value,
              child: const Icon(
                Icons.search,
                size: 80,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Recherche en cours$dots',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nous contactons les prestataires disponibles près de vous.\n'
            'Vous serez notifié dès qu\'un prestataire accepte.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),
          const SizedBox(height: 48),
          // Bouton annuler (optionnel)
          TextButton.icon(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Annuler la recherche'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
