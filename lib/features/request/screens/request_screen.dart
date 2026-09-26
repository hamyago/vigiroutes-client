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

  // ── Attente prestataire apres soumission ──────────────────────────────────
  bool   _isSearching      = false;
  Timer? _searchTimeoutTimer;
  String? _searchingInterventionId;

  // FIX Bug C : etat "prestataire trouve" pour afficher la page de confirmation
  // Avant ce fix : quand FCM intervention_update(accepted) arrivait,
  // _cancelSearch() mettait _isSearching=false et le body revenait sur
  // _ConfirmStep (le formulaire pre-soumission), completement vide visuellement.
  // Maintenant : on passe par _ProviderFoundView qui affiche les infos
  // du prestataire et un bouton "Suivre" vers /user/tracking/$id.
  bool    _providerFound         = false;
  String? _foundInterventionId;

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

    _fcmSubscription?.cancel();
    _fcmSubscription =
        FirebaseMessaging.onMessage.listen(_onFcmDuringSearch);
  }

  void _onFcmDuringSearch(RemoteMessage message) {
    if (!mounted || !_isSearching) return;
    final type = message.data['type'] as String?;
    final id   = message.data['intervention_id'] as String?;

    final isOurIntervention =
        id == null || id == _searchingInterventionId;
    if (!isOurIntervention) return;

    if (type == 'no_provider') {
      _cancelSearch();
      _showNoProviderDialog();
    } else if (type == 'intervention_update') {
      final status = message.data['status'] as String?;
      if (status == 'accepted' ||
          status == 'dispatched' ||
          status == 'en_route') {
        // FIX Bug C : ne pas naviguer immediatement — afficher la
        // page de confirmation d'abord, avec le bouton "Suivre".
        _cancelSearch();
        if (id != null && mounted) {
          setState(() {
            _providerFound       = true;
            _foundInterventionId = id;
          });
        }
      } else if (status == 'cancelled' ||
          status == 'rejected' ||
          status == 'failed') {
        _cancelSearch();
        _showNoProviderDialog(
          title: 'Demande annulee',
          message: 'La demande a ete annulee. Veuillez reessayer.',
        );
      }
    }
  }

  void _cancelSearch() {
    _searchTimeoutTimer?.cancel();
    _searchTimeoutTimer = null;
    _searchingInterventionId = null;
    _fcmSubscription?.cancel();
    _fcmSubscription = null;
    if (mounted) setState(() { _isSearching = false; });
  }

  Future<void> _showNoProviderDialog({
    String title   = 'Prestataires indisponibles',
    String message =
        'Aucun prestataire n\'est disponible dans votre zone pour le moment.\n\n'
        'Reessayez dans quelques minutes ou modifiez votre demande.',
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            child: const Text('Reessayer'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    FirebaseCrashlytics.instance.log(
        'RequestScreen.initState provider=${widget.preselectedProvider?.id ?? "aucun"}');

    _watchdog = Timer(const Duration(seconds: 20), _reportIfStuck);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _postFrameFired = true;
      FirebaseCrashlytics.instance
          .log('RequestScreen: appel ctrl.initialize()');
      await context.read<RequestController>().initialize(
            preselectedProvider: widget.preselectedProvider,
            mode: widget.mode,
          );
      _initializeDone = true;
      FirebaseCrashlytics.instance
          .log('RequestScreen: ctrl.initialize() termine');
      _watchdog?.cancel();
    });
  }

  void _reportIfStuck() {
    if (!mounted) return;
    final ctrl = context.read<RequestController>();

    final String reason;
    if (!_postFrameFired) {
      reason =
          'addPostFrameCallback jamais declenche (le widget n\'a peut-etre '
          'jamais fini de se construire)';
    } else if (!_initializeDone) {
      reason =
          'ctrl.initialize() appele mais jamais termine apres 20s '
          '(bloque dans ServiceTypeService.load, getCurrentPosition, ou ailleurs '
          'malgre les timeouts internes)';
    } else if (ctrl.userPosition == null && ctrl.error == null) {
      reason =
          'initialize() termine mais userPosition et error restent null';
    } else {
      return;
    }

    FirebaseCrashlytics.instance.recordError(
      Exception('RequestScreen bloque 20s+ : $reason'),
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
    _fcmSubscription?.cancel();
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
            if (_providerFound) {
              // Reset l'etat et retourner a l'accueil
              setState(() {
                _providerFound       = false;
                _foundInterventionId = null;
              });
              context.pop();
              return;
            }
            if (_isSearching) {
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
      // FIX Bug C : trois etats possibles pour le body :
      //   1. _isSearching      → spinner "Recherche en cours"
      //   2. _providerFound    → page de confirmation prestataire
      //   3. sinon             → etapes normales du formulaire
      body: _isSearching
          ? _SearchingProviderView(onCancel: _cancelSearch)
          : _providerFound
              ? _ProviderFoundView(
                  interventionId: _foundInterventionId!,
                  onTrack: () {
                    if (_foundInterventionId != null) {
                      context.go('/user/tracking/$_foundInterventionId');
                    }
                  },
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: switch (ctrl.step) {
                    RequestStep.selectService =>
                      _SelectServiceStep(ctrl: ctrl),
                    RequestStep.selectProvider =>
                      _SelectProviderStep(ctrl: ctrl),
                    RequestStep.confirm => _ConfirmStep(
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

// ── FIX Bug C : page de confirmation prestataire trouve ──────────────────────
// Affichee quand FCM intervention_update(accepted) arrive pendant la recherche.
// Remplace le formulaire vide qui s'affichait avant ce fix.
class _ProviderFoundView extends StatelessWidget {
  final String interventionId;
  final VoidCallback onTrack;

  const _ProviderFoundView({
    required this.interventionId,
    required this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade600,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Prestataire trouve !',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Un prestataire a accepte votre demande et est en route.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTrack,
                icon: const Icon(Icons.location_on),
                label: const Text(
                  'Suivre le prestataire',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(stService.error!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => stService.load(force: true),
              child: const Text('Reessayer'),
            ),
          ],
        ),
      );
    }

    final all = stService.serviceTypes;
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
            "Ce prestataire n'a pas encore renseigne ses services.",
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
                'a partir de ${service.formattedBasePrice}',
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
  bool _noPosition = false;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final pos       = widget.ctrl.userPosition;
    final serviceId = widget.ctrl.selectedService?.id;
    if (pos == null) {
      FirebaseCrashlytics.instance.recordError(
        Exception(
            '_SelectProviderStep: userPosition null, impossible de charger les prestataires'),
        StackTrace.current,
        fatal: false,
      );
      if (mounted) {
        setState(() {
          _loading    = false;
          _noPosition = true;
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
      final data = await ApiService.instance
          .getNearbyProviders(
            latitude:      pos.latitude,
            longitude:     pos.longitude,
            serviceTypeId: serviceId,
          )
          .timeout(const Duration(seconds: 30));
      if (mounted) {
        setState(() {
          _providers = data
              .map((e) =>
                  ProviderModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      FirebaseCrashlytics.instance.log(
          '[_SelectProviderStep] getNearbyProviders erreur: $e');
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
              const Icon(Icons.location_off,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Position GPS indisponible.\nActivez le GPS et reessayez.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProviders,
                child: const Text('Reessayer'),
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
              const Icon(Icons.search_off,
                  size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                service != null
                    ? 'Aucun prestataire disponible pour "${service.name}" pres de vous.'
                    : 'Aucun prestataire disponible pres de vous.',
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style:
                    const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(p.name,
                style:
                    const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.distanceKm != null)
                  Text('📍 ${p.distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 12)),
                Row(children: [
                  const Icon(Icons.star,
                      size: 14, color: Colors.amber),
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
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recapitulatif',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 12),
                  _Row('Service',
                      ctrl.selectedService?.name ?? '—'),
                  if (ctrl.selectedProvider != null)
                    _Row('Prestataire',
                        ctrl.selectedProvider!.name),
                  if (ctrl.isAuto)
                    const _Row('Affectation', 'Automatique'),
                  _Row('Position',
                      ctrl.userAddress ?? 'Position GPS'),
                  _Row('Paiement',
                      _paymentLabel(ctrl.paymentMethod)),
                  if (ctrl.estimateLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    )
                  else if (ctrl.estimate != null) ...[
                    const Divider(height: 20),
                    if (_estimateNum(
                            ctrl.estimate!['distance_km']) >
                        0)
                      _Row(
                          'Distance',
                          '${_estimateNum(ctrl.estimate!['distance_km']).toStringAsFixed(1)} km'),
                    _Row('Prix de base',
                        _fmt(_estimateNum(
                            ctrl.estimate!['base_price']))),
                    if (_estimateNum(
                            ctrl.estimate!['km_cost']) >
                        0)
                      _Row(
                          'Deplacement',
                          _fmt(_estimateNum(
                              ctrl.estimate!['km_cost']))),
                    _Row(
                      'Total estime',
                      _fmt(_estimateNum(
                          ctrl.estimate!['total_price'])),
                      bold: true,
                      valueColor: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Mode de paiement',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16)),
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
                  style:
                      const TextStyle(color: AppColors.error)),
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
              final ok =
                  await ctrl.submitRequest(user: auth.user!);
              if (!ok || !context.mounted) return;

              final interventionId = ctrl.createdInterventionId;
              if (interventionId == null) return;

              if (ctrl.isAuto) {
                onSubmitted?.call(interventionId);
              } else {
                context.go('/user/tracking/$interventionId');
              }
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              ctrl.isAuto
                  ? 'Nous contactons le meilleur prestataire disponible pres de vous. Le deplacement sera ajoute une fois le prestataire trouve.'
                  : 'Le prestataire sera notifie immediatement.',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) =>
      '${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} FCFA';

  String _paymentLabel(String method) => switch (method) {
        'cash'         => 'Especes',
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
              style: const TextStyle(
                  color: AppColors.textSecondary)),
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
      ('cash',         '💵 Especes'),
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
                  onChanged: (v) {
                    if (v != null) onSelect(v);
                  },
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

// ── Vue "Recherche prestataire en cours" ──────────────────────────────────────
class _SearchingProviderView extends StatefulWidget {
  final VoidCallback onCancel;
  const _SearchingProviderView({required this.onCancel});

  @override
  State<_SearchingProviderView> createState() =>
      _SearchingProviderViewState();
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

    _dotTimer =
        Timer.periodic(const Duration(milliseconds: 500), (_) {
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
            'Nous contactons les prestataires disponibles pres de vous.\n'
            'Vous serez notifie des qu\'un prestataire accepte.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: AppColors.textMuted),
          ),
          const SizedBox(height: 48),
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
