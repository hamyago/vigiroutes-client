import '../../../core/models/models.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../controllers/home_controller.dart';
import '../../../core/constants/app_colors.dart';
// import provider_card supprimé

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  GoogleMapController? _mapController;
  final _draggableController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeController>().initialize();
    });
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
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: ctrl.userPosition!,
                zoom: 14,
              ),
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
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
                          Text(
                            'Trouver un prestataire...',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Bouton notifications
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
                      icon: const Icon(Icons.notifications_outlined,
                          size: 20, color: AppColors.textPrimary),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bouton profil (restauré)
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
                      icon: const Icon(Icons.person_outline,
                          size: 20, color: AppColors.textPrimary),
                      onPressed: () => context.push('/user/profile'),
                    ),
                  ),
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
                  itemCount: ctrl.serviceTypes.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _FilterChip(
                        label: 'Tous',
                        selected: ctrl.selectedServiceFilter == null,
                        onTap: () => ctrl.setServiceFilter(null),
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

          // ── SOS Button ───────────────────────────────────────────────────
          Positioned(
            bottom: 240,
            right: 16,
            child: GestureDetector(
              onTap: () => context.push('/user/request'),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🆘', style: TextStyle(fontSize: 24)),
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Recenter button ───────────────────────────────────────────────
          Positioned(
            bottom: 240,
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
                onPressed: () {
                  if (ctrl.userPosition != null) {
                    _animateTo(ctrl.userPosition!);
                  }
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
                          '${ctrl.providers.length} prestataire(s) nearby',
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
                    child: ctrl.providers.isEmpty && !ctrl.isLoading
                        ? _EmptyProviders()
                        : ListView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: ctrl.providers.length,
                            itemBuilder: (_, i) => _ProviderTile(
                              provider: ctrl.providers[i],
                              onTap: () => context.push('/user/request', extra: ctrl.providers[i]),
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
                const Icon(Icons.location_off, size: 64, color: AppColors.textMuted),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFFFF0EB),
          child: Text(provider.serviceTypes.isNotEmpty ? '🔧' : '🛠️'),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(provider.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('★ ${provider.rating.toStringAsFixed(1)} · ${provider.serviceTypes.take(2).join(', ')}',
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ])),
        const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
      ]),
    ),
  );
}
