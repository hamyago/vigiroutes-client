import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/price_calculator.dart';
import '../../../shared/utils/date_filter_utils.dart';
import '../../../shared/widgets/date_range_filter.dart';
import '../widgets/vehicle_stats_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// Filtre période sélectionné (S14).
  DateFilter _selectedFilter = DateFilter.all;

  /// Filtre véhicule sélectionné (S15). null = tous les véhicules.
  String? _selectedVehicleId;

  /// Liste des véhicules de l'utilisateur (pour le filtre).
  List<VehicleModel> _vehicles = [];

  /// Liste complète des interventions (avant filtre période).
  List<InterventionModel> _interventions = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  /// Charge les véhicules + interventions (S18 : auto-sélection si 1 seul).
  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      // 1) Charger les véhicules D'ABORD
      final rawVehicles = (await ApiService.instance.getVehicles()) as List? ?? [];

      final vehicles = rawVehicles
          .map((e) {
            try { return VehicleModel.fromJson(e as Map<String, dynamic>); }
            catch (_) { return null; }
          })
          .whereType<VehicleModel>()
          .toList();

      // 2) Auto-sélection si l'utilisateur a exactement 1 véhicule (S18)
      String? effectiveVehicleId = _selectedVehicleId;
      if (vehicles.length == 1 && _selectedVehicleId == null) {
        effectiveVehicleId = vehicles.first.id;
      }

      // 3) Charger les interventions avec le filtre effectif
      final rawInterventions =
          (await ApiService.instance.getInterventions(
        vehicleId: effectiveVehicleId,
      )) as List? ??
              [];

      if (!mounted) return;

      setState(() {
        _vehicles = vehicles;
        _selectedVehicleId = effectiveVehicleId;
        _interventions = rawInterventions
            .map((e) {
              try { return InterventionModel.fromJson(e as Map<String, dynamic>); }
              catch (_) { return null; }
            })
            .whereType<InterventionModel>()
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Recharge uniquement les interventions (changement de véhicule).
  Future<void> _reloadInterventions() async {
    setState(() { _loading = true; _error = null; });
    try {
      final raw = await ApiService.instance.getInterventions(
        vehicleId: _selectedVehicleId,
      );
      if (!mounted) return;
      setState(() {
        _interventions = raw
            .map((e) {
              try { return InterventionModel.fromJson(e as Map<String, dynamic>); }
              catch (_) { return null; }
            })
            .whereType<InterventionModel>()
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Change le véhicule sélectionné et recharge.
  void _onVehicleChanged(String? vehicleId) {
    if (_selectedVehicleId == vehicleId) return;
    setState(() => _selectedVehicleId = vehicleId);
    _reloadInterventions();
  }

  /// Filtre les interventions par période (client-side).
  List<InterventionModel> get _filtered => _interventions
      .where((i) => matchesDateFilter(i.createdAt, _selectedFilter))
      .toList();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/user/home');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes interventions'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/user/home'),
          ),
        ),
        body: Column(
          children: [
            // Filtre véhicule (S15) — affiché seulement si >1 véhicule
            if (_vehicles.length > 1) _buildVehicleChips(),
            // Filtre période (S14)
            DateRangeFilter(
              selected: _selectedFilter,
              onChanged: (f) => setState(() => _selectedFilter = f),
            ),
            // Stats du véhicule sélectionné (S18)
            if (_selectedVehicleId != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                ),
                child: VehicleStatsCard(vehicleId: _selectedVehicleId!),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  /// Chips véhicule (S15).
  Widget _buildVehicleChips() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _vehicles.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            // "Tous les véhicules"
            return _chip(
              label: 'Tous',
              isSelected: _selectedVehicleId == null,
              onTap: () => _onVehicleChanged(null),
            );
          }
          final v = _vehicles[i - 1];
          return _chip(
            label: v.plate,
            isSelected: _selectedVehicleId == v.id,
            onTap: () => _onVehicleChanged(v.id),
          );
        },
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Erreur : $_error'));
    }
    final list = _filtered;
    if (list.isEmpty) return _Empty();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => _InterventionTile(
        intervention: list[i],
        onTap: () {
          if (list[i].isActive) context.go('/user/tracking/${list[i].id}');
        },
      ),
    );
  }
}

class _InterventionTile extends StatelessWidget {
  final InterventionModel intervention;
  final VoidCallback onTap;
  const _InterventionTile({required this.intervention, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = intervention.noProviderAvailable
        ? ('Indisponible', AppColors.error)
        : _statusInfo(intervention.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_serviceIcon(intervention.serviceTypeId), style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(intervention.serviceTypeName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text(timeago.format(intervention.createdAt, locale: 'fr'),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _Info(icon: Icons.person_outline, label: intervention.provider?.name ?? 'Non assigné'),
            const Spacer(),
            Text(PriceCalculator.formatFcfa(intervention.totalPrice),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 15)),
          ]),
          if (intervention.userAddress != null) ...[
            const SizedBox(height: 6),
            _Info(icon: Icons.location_on_outlined, label: intervention.userAddress!),
          ],
          const SizedBox(height: 10),
          if (intervention.status == 'completed' || intervention.status == 'cancelled')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/user/request'),
                icon: const Icon(Icons.sos, size: 16),
                label: const Text('Faire appel a un prestataire'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  String _serviceIcon(String id) {
    const icons = {
      'mechanic': '🔧', 'towing': '🚛', 'tire': '🔩',
      'electrical': '⚡', 'battery': '🔋', 'fuel': '⛽',
      'locksmith': '🔑', 'other': '🛠️',
    };
    return icons[id] ?? '🛠️';
  }

  (String, Color) _statusInfo(String status) => switch (status) {
        'pending'     => ('En attente', AppColors.warning),
        'dispatching' => ('Recherche en cours', AppColors.warning),
        'accepted'    => ('Acceptee', AppColors.primary),
        'in_progress' => ('En cours', AppColors.success),
        'completed'   => ('Terminee', AppColors.success),
        'cancelled'   => ('Annulee', AppColors.error),
        _             => ('Inconnu', AppColors.textMuted),
      };
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Info({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Flexible(child: Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis)),
        ],
      );
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🚗', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Aucune intervention',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Vos demandes de depannage apparaitront ici.',
              style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/user/request'),
            icon: const Icon(Icons.sos),
            label: const Text('Faire appel a un prestataire'),
          ),
        ]),
      );
}
