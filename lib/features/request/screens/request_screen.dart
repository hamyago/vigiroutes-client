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
  const RequestScreen({super.key, this.preselectedProvider});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestController>().initialize(
            preselectedProvider: widget.preselectedProvider,
          );
    });
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (ctrl.step) {
          RequestStep.selectService  => _SelectServiceStep(ctrl: ctrl),
          RequestStep.selectProvider => _SelectProviderStep(ctrl: ctrl),
          RequestStep.confirm        => _ConfirmStep(ctrl: ctrl),
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

  Future<void> _loadProviders() async {
    final pos       = widget.ctrl.userPosition;
    final serviceId = widget.ctrl.selectedService?.id;
    if (pos == null) return;
    try {
      final data = await ApiService.instance.getNearbyProviders(
        latitude:      pos.latitude,
        longitude:     pos.longitude,
        serviceTypeId: serviceId,
      );
      if (mounted) setState(() {
        _providers = data
            .map((e) => ProviderModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.ctrl.selectedService;
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: AppColors.primaryLight,
        child: Text(
          'Service : ${service?.emoji} ${service?.name}',
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _providers.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('😔', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text(
                          'Aucun prestataire disponible\ndans un rayon de 10 km.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _providers.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ProviderTile(
                      provider: _providers[i],
                      onTap: () =>
                          widget.ctrl.selectProvider(_providers[i]),
                    ),
                  ),
      ),
    ]);
  }
}

class _ProviderTile extends StatelessWidget {
  final ProviderModel provider;
  final VoidCallback onTap;
  const _ProviderTile({required this.provider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Résoudre l'emoji depuis le slug ou l'ID
    final stService = ServiceTypeService.instance;
    String emoji = '🛠️';
    if (provider.serviceTypes.isNotEmpty) {
      final raw = provider.serviceTypes.first;
      final st  = stService.findById(raw) ?? stService.findBySlug(raw);
      emoji     = st?.emoji ?? '🛠️';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8)
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: provider.photoUrl != null
                  ? NetworkImage(provider.photoUrl!) : null,
              child: provider.photoUrl == null
                  ? Text(emoji,
                      style: const TextStyle(fontSize: 20)) : null,
            ),
            if (provider.isAvailable)
              Positioned(
                right: -2, bottom: -2,
                child: Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(provider.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(children: [
          const Icon(Icons.star, size: 13, color: Colors.amber),
          const SizedBox(width: 3),
          Text(provider.rating.toStringAsFixed(1),
              style: const TextStyle(fontSize: 12)),
          if (provider.distanceKm != null) ...[
            const Text('  ·  ',
                style: TextStyle(color: AppColors.textMuted)),
            const Icon(Icons.location_on,
                size: 13, color: AppColors.textMuted),
            Text(' ${provider.distanceKm!.toStringAsFixed(1)} km',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted)),
          ],
        ]),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textMuted),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: provider.isAvailable
                    ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                provider.isAvailable ? 'Disponible' : 'Occupé',
                style: TextStyle(
                  fontSize: 10,
                  color: provider.isAvailable
                      ? Colors.green.shade700 : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        onTap: provider.isAvailable ? onTap : null,
      ),
    );
  }
}

// ── Step 3: Confirm ───────────────────────────────────────────────────────────

class _ConfirmStep extends StatelessWidget {
  final RequestController ctrl;
  const _ConfirmStep({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthController>();
    final estimate = ctrl.estimate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row('🛠️ Service',
                    '${ctrl.selectedService?.emoji} ${ctrl.selectedService?.name}'),
                const Divider(height: 20),
                _Row('👨‍🔧 Prestataire',
                    ctrl.selectedProvider?.name ?? '-'),
                _Row('📍 Distance',
                    '${_estimateNum(estimate?['distance_km']).toStringAsFixed(1)} km'),
                const Divider(height: 20),
                _Row('Prix de base',
                    PriceCalculator.formatFcfa(
                        _estimateNum(estimate?['base_price']))),
                _Row('Déplacement',
                    PriceCalculator.formatFcfa(
                        _estimateNum(estimate?['km_cost']))),
                const Divider(height: 20),
                _Row('TOTAL',
                    PriceCalculator.formatFcfa(
                        _estimateNum(estimate?['total_price'])),
                    bold: true,
                    valueColor: AppColors.primary),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Mode de paiement',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 12),
          _PaymentMethods(
            selected: ctrl.paymentMethod,
            onSelect: ctrl.setPaymentMethod,
          ),

          if (ctrl.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
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
              if (ok && context.mounted) {
                context.go(
                    '/user/tracking/${ctrl.createdInterventionId}');
              }
            },
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Le prestataire sera notifié immédiatement.',
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
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
          .map<Widget>((m) => RadioListTile<String>(
                value: m.$1,
                groupValue: selected,
                title: Text(m.$2),
                activeColor: AppColors.primary,
                onChanged: (v) => onSelect(v!),
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
