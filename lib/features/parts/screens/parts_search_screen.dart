import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';

/// Recherche de pièces automobiles (Client).
///
/// Nouveautés v2 :
///   • Affiche les magasins les plus proches dès l'ouverture de l'écran,
///     avant toute saisie — triés par distance.
///   • Recherche flexible : « frein », « Frein », « Freins » → même résultat.
///     La normalisation (minuscules + suppression des accents + désinflexion)
///     est effectuée côté Flutter avant l'envoi du paramètre `q`, et le
///     backend applique `unaccent + ILIKE` pour matcher côté PostgreSQL.
///   • Dès la frappe, les résultats sont triés : d'abord les magasins qui
///     ont la pièce EN STOCK, puis par distance.
class PartsSearchScreen extends StatefulWidget {
  const PartsSearchScreen({super.key});

  @override
  State<PartsSearchScreen> createState() => _PartsSearchScreenState();
}

class _PartsSearchScreenState extends State<PartsSearchScreen> {
  final _searchCtrl = TextEditingController();
  final _location   = LocationService();
  Timer? _debounce;

  // Magasins proches (chargés au démarrage, sans recherche)
  List<StoreModel> _nearby     = [];
  bool             _loadingNearby = true;
  String?          _nearbyError;

  // Résultats de recherche
  List<StoreModel> _results   = [];
  bool             _searching = false;
  bool             _searched  = false;
  String?          _error;

  @override
  void initState() {
    super.initState();
    _loadNearbyStores();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Normalisation locale ───────────────────────────────────────────────────
  // Transforme « Freins », « FREIN », « frein » → « frein »
  // Supprime aussi les accents courants pour être cohérent avec unaccent() PG.
  static String _normalize(String s) {
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
      'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o', 'ò': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    var out = s.toLowerCase().trim();
    for (final e in accents.entries) {
      out = out.replaceAll(e.key, e.value);
    }
    // Désinflexion minimale : retire le « s » final pour unifier singulier/pluriel.
    // Le backend applique lui aussi `unaccent + ILIKE '%term%'` donc un mot
    // tronqué sans le « s » matche toujours le pluriel en base.
    if (out.length > 3 && out.endsWith('s')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  // ── Chargement initial : magasins proches ──────────────────────────────────
  Future<void> _loadNearbyStores() async {
    setState(() {
      _loadingNearby = true;
      _nearbyError   = null;
    });
    try {
      final pos = await _location.getCurrentPosition();
      if (pos == null) {
        setState(() {
          _loadingNearby = false;
          _nearbyError   = 'Position indisponible.';
        });
        return;
      }
      final data = await ApiService.instance.getNearbyStores(
        latitude:  pos.latitude,
        longitude: pos.longitude,
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _nearby        = data.map((e) => StoreModel.fromJson(e as Map<String, dynamic>)).toList();
        _loadingNearby = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingNearby = false;
        _nearbyError   = 'Impossible de charger les magasins proches.';
      });
    }
  }

  // ── Recherche dynamique ────────────────────────────────────────────────────
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _results  = [];
        _searched = false;
        _error    = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final raw = _searchCtrl.text.trim();
    if (raw.length < 2) {
      setState(() => _error = 'Saisissez au moins 2 caractères.');
      return;
    }
    setState(() {
      _searching = true;
      _searched  = true;
      _error     = null;
    });
    try {
      final pos = await _location.getCurrentPosition();
      if (pos == null) {
        setState(() {
          _searching = false;
          _error     = 'Impossible d\'obtenir votre position.';
        });
        return;
      }
      // On envoie le terme normalisé — le backend n'a plus à gérer la casse
      // ni les accents côté requête (il le fait quand même avec unaccent).
      final data = await ApiService.instance.searchParts(
        query:     _normalize(raw),
        latitude:  pos.latitude,
        longitude: pos.longitude,
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;

      final stores = data
          .map((e) => StoreModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Tri client : stock disponible en premier, puis distance croissante.
      stores.sort((a, b) {
        final aHas = a.products.any((p) => p.isAvailable) ? 0 : 1;
        final bHas = b.products.any((p) => p.isAvailable) ? 0 : 1;
        if (aHas != bHas) return aHas.compareTo(bHas);
        final aDist = a.distanceKm ?? 999;
        final bDist = b.distanceKm ?? 999;
        return aDist.compareTo(bDist);
      });

      setState(() {
        _results   = stores;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error     = 'Erreur lors de la recherche. Réessayez.';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pièces auto',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.primary),
            tooltip: 'Mes commandes',
            onPressed: () => context.push('/user/parts/orders'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barre de recherche ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SearchBar(
              controller: _searchCtrl,
              hintText: 'Ex: plaquette de frein, batterie, pneu...',
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _search(),
              leading: const Icon(Icons.search),
              trailing: [
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search,
                  ),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),

          // ── Corps ──────────────────────────────────────────────────────
          Expanded(
            child: _searched
                // Résultats de recherche
                ? _results.isEmpty && !_searching
                    ? _buildEmpty()
                    : _buildResultsList()
                // État initial : magasins proches
                : _buildNearbySection(),
          ),
        ],
      ),
    );
  }

  // ── Section magasins proches (état initial) ────────────────────────────────
  Widget _buildNearbySection() {
    if (_loadingNearby) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_nearbyError != null && _nearby.isEmpty) {
      return _buildIntroFallback();
    }
    if (_nearby.isEmpty) {
      return _buildIntroFallback();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.location_on, size: 15, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Magasins les plus proches',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _nearby.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _StoreCard(
              store: _nearby[i],
              showAvailability: false,
              onTap: () => context.push(
                  '/user/parts/store/${_nearby[i].id}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntroFallback() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔩', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              const Text('Cherchez une pièce',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'On vous montrera les magasins à moins de 3 km qui la vendent.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );

  // ── Liste des résultats de recherche ───────────────────────────────────────
  Widget _buildResultsList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _StoreCard(
        store: _results[i],
        showAvailability: true,
        onTap: () => context.push(
            '/user/parts/store/${_results[i].id}?q=${Uri.encodeComponent(_searchCtrl.text.trim())}'),
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text('Aucun magasin trouvé à proximité',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Essayez un autre nom de produit, ou réessayez plus tard.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
}

// ── Card magasin ───────────────────────────────────────────────────────────────
class _StoreCard extends StatelessWidget {
  final StoreModel store;
  final bool       showAvailability;
  final VoidCallback onTap;

  const _StoreCard({
    required this.store,
    required this.showAvailability,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasStock = store.products.any((p) => p.isAvailable);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            // Avatar magasin
            Container(
              width: 46, height: 46,
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Center(child: Text('🏬', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom + badge disponibilité
                  Row(
                    children: [
                      Expanded(
                        child: Text(store.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (showAvailability)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasStock
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            hasStock ? 'En stock' : 'Non dispo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasStock
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (store.address != null) ...[
                    const SizedBox(height: 2),
                    Text(store.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],

                  const SizedBox(height: 4),
                  Row(children: [
                    if (store.distanceKm != null) ...[
                      const Icon(Icons.location_on,
                          size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Text('${store.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(width: 10),
                    ],
                    if (store.products.isNotEmpty)
                      Flexible(
                        child: Text(
                          '${store.products.first.name}'
                          ' — ${store.products.first.unitPrice.toStringAsFixed(0)} F',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ]),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
