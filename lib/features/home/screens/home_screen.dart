import '../../../core/models/models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../shared/navigation/app_router.dart' show homeRouteObserver;

/// DIAGNOSTIC : true = remplace GoogleMap par un cadre neutre.
/// Remis à false : la cause du crash était l'absence de HomeController.
const bool _kDiagnoseDisableMap = false;

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> with RouteAware {
  GoogleMapController? _mapController;
  final _draggableController = DraggableScrollableController();
  // AJOUTÉ : pastille sur la cloche — aucun indicateur visuel n'existait
  // avant pour signaler des notifications non lues.
  int _unreadCount = 0;

  // BUG CORRIGÉ : la carte Google Maps restait active en arrière-plan
  // (jamais disposée) quand un écran était poussé par-dessus l'accueil
  // (ex: Pièces auto) — une PlatformView de carte active en dessous peut
  // bloquer l'affichage du clavier sur l'écran du dessus (bug documenté
  // Flutter/Android). On masque maintenant la carte dès qu'un autre
  // écran passe au premier plan, et on la restaure au retour.
  bool _routeIsCurrent = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeController>().initialize();
    });
    _loadUnreadCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      homeRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    homeRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    // Un écran vient d'être poussé par-dessus l'accueil (ex: Pièces auto).
    if (mounted) setState(() => _routeIsCurrent = false);
  }

  @override
  void didPopNext() {
    // Retour sur l'accueil après avoir fermé l'écran poussé par-dessus.
    if (mounted) setState(() => _routeIsCurrent = true);
  }

  Future<void> _loadUnreadCount() async {
    final count = await ApiService.instance.getUnreadNotificationsCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  void _animateTo(LatLng pos) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: pos, zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<HomeController>();

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          if (ctrl.userPosition != null)
            (_kDiagnoseDisableMap || !_routeIsCurrent)
                ? Container(
                    color: const Color(0xFFDDE6F0),
                    alignment: Alignment.center,
                    child: _routeIsCurrent
                        ? const Text(
                            'CARTE DESACTIVEE (diagnostic)',
                            style: TextStyle(color: Colors.black54, fontSize: 16),
                          )
                        : null,
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: ctrl.userPosition!,
                      zoom: 14,
                    ),
                    onMapCreated: (c) => _mapController = c,
                    myLocationEnabled: !ctrl.locationApprox,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    markers: ctrl.markers,
                  )
          else if (ctrl.error != null)
            _MapError(
              message: ctrl.error!,
              onRetry: () => ctrl.initialize(),
            )
          else
            Container(
              color: AppColors.background,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // ── Top bar ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search,
                              color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              onChanged: ctrl.setSearchQuery,
                              textInputAction: TextInputAction.search,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Trouver un prestataire...',
                                hintStyle: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 14,
                                ),
                              ),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // AJOUTÉ : accès à la recherche de pièces automobiles.
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.build_circle_outlined,
                          size: 20, color: AppColors.textPrimary),
                      tooltip: 'Pièces auto',
                      onPressed: () => context.push('/user/parts'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              size: 20, color: AppColors.textPrimary),
                          // BUG CORRIGÉ : onPressed: () {} — ne faisait
                          // littéralement rien au clic.
                          onPressed: () async {
                            await context.push('/user/notifications');
                            // Rafraîchit la pastille au retour (l'écran de
                            // notifications marque tout comme lu à l'ouverture).
                            _loadUnreadCount();
                          },
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // RETIRÉ : icône profil en haut — redondante avec l'onglet
                  // "Profil" déjà présent dans la barre de navigation du bas,
                  // comme demandé.
                ],
              ),
            ),
          ),

          // ── Service type chips ────────────────────────────────────────────
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // +2 : le chip "Tous" en premier, "Pièces auto" en dernier
                  // (AJOUTÉ — navigue vers la recherche de pièces au lieu de
                  // filtrer les prestataires, contrairement aux autres chips).
                  itemCount: ctrl.serviceTypes.length + 2,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _FilterChip(
                        label: 'Tous',
                        selected: ctrl.selectedServiceFilter == null,
                        onTap: () => ctrl.setServiceFilter(null),
                      );
                    }
                    if (i == ctrl.serviceTypes.length + 1) {
                      return _FilterChip(
                        label: '🔩 Pièces auto',
                        selected: false,
                        onTap: () => context.push('/user/parts'),
                      );
                    }
                    final s = ctrl.serviceTypes[i - 1];
                    return _FilterChip(
                      label: '${s.icon} ${s.name}',
                      selected: ctrl.selectedServiceFilter == s.id,
                      onTap: () => ctrl.setServiceFilter(s.id),
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Recenter button ───────────────────────────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.28 + 16,
            left: 16,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location,
                    size: 20, color: AppColors.primary),
                onPressed: () async {
                  final pos = await ctrl.refreshLocation();
                  final target = pos ?? ctrl.userPosition;
                  if (target != null) _animateTo(target);
                },
              ),
            ),
          ),

          // ── Bottom sheet: provider list ──────────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize: 0.12,
            maxChildSize: 0.75,
            controller: _draggableController,
            builder: (_, scrollCtrl) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          '${ctrl.visibleProviders.length} prestataire(s) à proximité',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        if (ctrl.isLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ctrl.visibleProviders.isEmpty && !ctrl.isLoading
                        ? _EmptyProviders()
                        : ListView.builder(
                            controller: scrollCtrl,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: ctrl.visibleProviders.length,
                            itemBuilder: (_, i) => _ProviderTile(
                              provider: ctrl.visibleProviders[i],
                              onTap: () => context.push('/user/request',
                                  extra: ctrl.visibleProviders[i]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
}

class _MapError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _MapError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off,
                    size: 64, color: AppColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EmptyProviders extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😔', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            const Text(
              'Aucun prestataire disponible dans un rayon de 10 km.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => context.push('/user/request'),
              icon: const Icon(Icons.sos, size: 16),
              label: const Text('Envoyer une demande urgente',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
}

class _ProviderTile extends StatelessWidget {
  final ProviderModel provider;
  final VoidCallback? onTap;
  const _ProviderTile({required this.provider, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
            ],
          ),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFFFF0EB),
              child: Text(
                  provider.serviceTypes.isNotEmpty ? '🔧' : '🛠️'),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(provider.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(
                      '★ ${provider.rating.toStringAsFixed(1)} · ${provider.serviceTypes.take(2).join(', ')}',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12)),
                ])),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ]),
        ),
      );
}