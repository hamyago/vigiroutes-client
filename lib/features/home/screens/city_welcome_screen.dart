import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/top_provider_model.dart';

/// Écran affiché quand l'utilisateur tape sur la notification
/// "Bienvenue à [Ville]" reçue à l'entrée dans une nouvelle ville.
///
/// Affiche le top 5 des prestataires de chaque secteur (Mécanicien,
/// Remorqueur, Vulcanisateur, Électricien auto), classés par un score
/// combinant note moyenne et nombre de courses effectuées.
class CityWelcomeScreen extends StatelessWidget {
  final String cityName;
  final Map<String, List<TopProviderModel>> topBySector;

  const CityWelcomeScreen({
    super.key,
    required this.cityName,
    required this.topBySector,
  });

  /// Construit l'écran à partir du payload `data` brut de la notification
  /// FCM (où top_providers est une chaîne JSON encodée côté backend).
  factory CityWelcomeScreen.fromNotificationData(Map<String, dynamic> data) {
    final city = data['city'] as String? ?? 'votre zone';
    final raw  = data['top_providers'] as String?;

    final Map<String, List<TopProviderModel>> parsed = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((sector, list) {
          parsed[sector] = (list as List)
              .map((p) => TopProviderModel.fromJson(p as Map<String, dynamic>))
              .toList();
        });
      } catch (_) {
        // Payload corrompu ou vide : on affiche l'écran avec des listes vides
        // plutôt que de planter — l'utilisateur verra juste "aucun résultat".
      }
    }

    return CityWelcomeScreen(cityName: city, topBySector: parsed);
  }

  @override
  Widget build(BuildContext context) {
    final sectorsWithData = ProviderSector.values
        .where((s) => (topBySector[s.apiValue]?.isNotEmpty ?? false))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── En-tête ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('👋', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 4),
                        Text(
                          'Bienvenue à $cityName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Voici les meilleurs prestataires de la zone',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Contenu ──────────────────────────────────────────────────
          if (sectorsWithData.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucun prestataire référencé dans cette zone pour le moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final sector = sectorsWithData[index];
                    final providers = topBySector[sector.apiValue] ?? [];
                    return _SectorSection(sector: sector, providers: providers);
                  },
                  childCount: sectorsWithData.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectorSection extends StatelessWidget {
  final ProviderSector sector;
  final List<TopProviderModel> providers;

  const _SectorSection({required this.sector, required this.providers});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(sector.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  sector.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...providers.asMap().entries.map(
                  (entry) => _ProviderRow(rank: entry.key + 1, provider: entry.value),
                ),
          ],
        ),
      );
}

class _ProviderRow extends StatelessWidget {
  final int rank;
  final TopProviderModel provider;

  const _ProviderRow({required this.rank, required this.provider});

  static const _medalColors = {
    1: Color(0xFFFFD700),
    2: Color(0xFFC0C0C0),
    3: Color(0xFFCD7F32),
  };

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Rang
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_medalColors[rank] ?? AppColors.surfaceVariant)
                    .withOpacity(rank <= 3 ? 1 : 0.5),
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: rank <= 3 ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: provider.photoUrl != null
                  ? NetworkImage(provider.photoUrl!)
                  : null,
              child: provider.photoUrl == null
                  ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                  : null,
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        '${provider.rating.toStringAsFixed(1)} (${provider.ratingCount})',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${provider.totalInterventions} courses',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Appel rapide
            if (provider.phone != null)
              IconButton(
                onPressed: () => launchUrl(Uri.parse('tel:${provider.phone}')),
                icon: const Icon(Icons.phone, color: AppColors.success, size: 20),
              ),
          ],
        ),
      );
}
