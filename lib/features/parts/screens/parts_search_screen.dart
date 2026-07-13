import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';

/// AJOUTÉ : recherche de pièces automobiles auprès des magasins à
/// proximité (rayon 3 km). Nouvelle fonctionnalité.
class PartsSearchScreen extends StatefulWidget {
  const PartsSearchScreen({super.key});

  @override
  State<PartsSearchScreen> createState() => _PartsSearchScreenState();
}

class _PartsSearchScreenState extends State<PartsSearchScreen> {
  final _searchCtrl = TextEditingController();
  final _location = LocationService();
  Timer? _debounce;

  List<StoreModel> _results = [];
  bool _searching = false;
  bool _searched = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Recherche dynamique : relancée à chaque frappe, avec un anti-rebond de
  /// 350 ms pour ne pas appeler l'API à chaque lettre. En dessous de 2
  /// caractères, on vide les résultats sans erreur (l'erreur ne s'affiche
  /// que sur une validation explicite).
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
    final query = _searchCtrl.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Saisissez au moins 2 caractères.');
      return;
    }
    setState(() {
      _searching = true;
      _searched = true;
      _error = null;
    });
    try {
      final pos = await _location.getCurrentPosition();
      if (pos == null) {
        setState(() {
          _searching = false;
          _error = 'Impossible d\'obtenir votre position. Vérifiez que la localisation est activée.';
        });
        return;
      }
      final data = await ApiService.instance.searchParts(
        query: query,
        latitude: pos.latitude,
        longitude: pos.longitude,
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _results = data.map((e) => StoreModel.fromJson(e as Map<String, dynamic>)).toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Erreur lors de la recherche. Réessayez.';
      });
    }
  }

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
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            // REFAIT DE ZÉRO : la Row/TextFormField personnalisée se
            // rendait cassée (trait fin + icône flottante, ni saisie ni
            // clavier possibles) de façon reproductible sur les deux
            // apps malgré plusieurs correctifs ciblés. Remplacé par le
            // widget SearchBar natif de Material 3 — composant standard
            // de Flutter, largement testé, qui gère nativement toute
            // l'interaction clavier/tactile sans décoration personnalisée.
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
              child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          Expanded(
            child: !_searched
                ? _buildIntro()
                : _results.isEmpty && !_searching
                    ? _buildEmpty()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _StoreCard(
                          store: _results[i],
                          onTap: () => context.push(
                              '/user/parts/store/${_results[i].id}?q=${Uri.encodeComponent(_searchCtrl.text.trim())}'),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() => Center(
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

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  final VoidCallback onTap;
  const _StoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Center(child: Text('🏬', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (store.address != null)
                    Text(store.address!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (store.distanceKm != null) ...[
                      const Icon(Icons.location_on, size: 13, color: AppColors.textMuted),
                      const SizedBox(width: 2),
                      Text('${store.distanceKm!.toStringAsFixed(1)} km',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(width: 10),
                    ],
                    if (store.products.isNotEmpty)
                      Text(
                        '${store.products.first.name} — ${store.products.first.unitPrice.toStringAsFixed(0)} F',
                        style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
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
