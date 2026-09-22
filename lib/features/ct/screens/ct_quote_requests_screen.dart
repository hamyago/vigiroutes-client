import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ct_quote_model.dart';
import '../controllers/ct_quote_controller.dart';

class CtQuoteRequestsScreen extends StatefulWidget {
  const CtQuoteRequestsScreen({super.key});

  @override
  State<CtQuoteRequestsScreen> createState() => _CtQuoteRequestsScreenState();
}

class _CtQuoteRequestsScreenState extends State<CtQuoteRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CtQuoteController>().loadRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Mes demandes de devis CT',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/ct/quote/new'),
            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
            label: const Text(
              'Nouveau',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Consumer<CtQuoteController>(
        builder: (context, ctrl, _) {
          if (ctrl.isLoadingList) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (ctrl.listError != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(ctrl.listError!, style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: ctrl.loadRequests,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Réessayer', style: TextStyle(fontFamily: 'Poppins', color: Colors.white)),
                  ),
                ],
              ),
            );
          }
          if (ctrl.requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.request_quote_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    'Aucune demande de devis',
                    style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Créez une demande pour obtenir un devis\navant votre contrôle technique.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/ct/quote/new'),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Nouvelle demande', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: ctrl.loadRequests,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ctrl.requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _RequestCard(
                request: ctrl.requests[i],
                onTap: () => context.push('/ct/quote/${ctrl.requests[i].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final CtQuoteRequestModel request;
  final VoidCallback onTap;

  const _RequestCard({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = _statusStyle(request.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demande #${request.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _transportLabel(request.transportMode),
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 11, color: color)),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(request.createdAt),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (Color, String, IconData) _statusStyle(String status) {
    return switch (status) {
      'pending'  => (AppColors.warning, 'En attente', Icons.schedule_rounded),
      'quoted'   => (AppColors.primary, 'Devis reçu', Icons.mark_email_read_rounded),
      'accepted' => (AppColors.success, 'Accepté', Icons.check_circle_rounded),
      'refused'  => (AppColors.error, 'Refusé', Icons.cancel_rounded),
      'expired'  => (AppColors.textMuted, 'Expiré', Icons.timer_off_rounded),
      'booked'   => (AppColors.success, 'RDV pris', Icons.event_available_rounded),
      _          => (AppColors.textMuted, status, Icons.help_outline_rounded),
    };
  }

  String _transportLabel(String mode) => switch (mode) {
    'tow'    => '🚛 Avec dépanneuse',
    'driver' => '🧑‍✈️ Avec chauffeur',
    _        => '🚗 Par mes propres moyens',
  };

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
