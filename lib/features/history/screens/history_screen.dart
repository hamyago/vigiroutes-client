import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/utils/price_calculator.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes interventions')),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.instance.getInterventions(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur : ${snap.error}'));
          }
          final rawList = snap.data ?? [];
          final List<InterventionModel> list = rawList
              .map((e) {
                try { return InterventionModel.fromJson(e as Map<String, dynamic>); }
                catch (_) { return null; }
              })
              .whereType<InterventionModel>()
              .toList();
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
    final (statusLabel, statusColor) = _statusInfo(intervention.status);
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
