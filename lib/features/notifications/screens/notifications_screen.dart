import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

/// Historique des notifications reçues par le client.
///
/// AJOUTÉ : la cloche sur l'écran d'accueil existait déjà visuellement
/// mais avec onPressed: () {} — ne faisait littéralement rien au clic.
/// Aucun historique de notifications n'existait nulle part (les push FCM
/// sont éphémères, jamais stockées) — nouvelle table app_notifications
/// créée côté backend, alimentée à chaque notification importante
/// envoyée au client (accepté, terminé, aucun prestataire...).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Marque comme lues en quittant l'écran — la surbrillance reste donc
    // visible pendant toute la consultation, même après un tirer-pour-
    // rafraîchir.
    ApiService.instance.markNotificationsRead();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final data = await ApiService.instance.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
      // MODIFIÉ : marquer comme lues seulement à la FERMETURE de l'écran
      // (voir dispose()), pas immédiatement au chargement — sinon la
      // surbrillance "non lue" disparaissait dès qu'on tirait pour
      // rafraîchir alors qu'on est encore en train de les consulter.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _onTap(Map<String, dynamic> n) {
    final data = n['data'] as Map<String, dynamic>?;
    final interventionId = data?['intervention_id'] as String?;
    if (interventionId != null) {
      context.push('/user/tracking/$interventionId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notifications',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.error, size: 48),
                          const SizedBox(height: 12),
                          const Text('Impossible de charger les notifications.'),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                        ],
                      ),
                    ),
                  )
                : _items.isEmpty
                    ? ListView(
                        // ListView (pas juste Center) pour que le
                        // RefreshIndicator fonctionne même sans contenu.
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Column(
                              children: [
                                Text('🔔', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 12),
                                Text('Aucune notification pour le moment',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final n = _items[i];
                          final unread = n['read_at'] == null;
                          DateTime? createdAt;
                          try {
                            createdAt = DateTime.parse(n['created_at'] as String);
                          } catch (_) {}
                          return InkWell(
                            onTap: () => _onTap(n),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                // MODIFIÉ : fond teinté (pas juste une fine
                                // bordure) pour que les non-lues soient
                                // vraiment visibles au premier coup d'œil.
                                color: unread ? AppColors.primaryLight : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: unread
                                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 6),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (unread)
                                    Container(
                                      margin: const EdgeInsets.only(top: 6, right: 10),
                                      width: 10, height: 10,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.4),
                                              blurRadius: 4),
                                        ],
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(n['title'] as String? ?? '',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      color: unread
                                                          ? AppColors.textPrimary
                                                          : AppColors.textSecondary)),
                                            ),
                                            if (unread)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary,
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: const Text('Nouveau',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(n['body'] as String? ?? '',
                                            style: const TextStyle(
                                                color: AppColors.textSecondary, fontSize: 13)),
                                        if (createdAt != null) ...[
                                          const SizedBox(height: 6),
                                          Text(timeago.format(createdAt, locale: 'fr'),
                                              style: const TextStyle(
                                                  color: AppColors.textMuted, fontSize: 11)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
