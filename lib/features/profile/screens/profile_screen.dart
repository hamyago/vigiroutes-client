import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/services/api_service.dart';

/// BUG CORRIGÉ : AuthController.user est chargé une seule fois au login
/// et jamais rafraîchi automatiquement — la note (moyenne calculée côté
/// serveur à partir des avis reçus des prestataires) restait donc figée
/// à "Pas encore noté" même après plusieurs avis reçus. refreshUser()
/// existait déjà (utilisé après changement de photo) mais n'était jamais
/// appelé à l'ouverture de cet écran. Même correctif déjà appliqué côté
/// app Pro (provider_info_screen.dart).
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().refreshUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar + name
            Center(
              child: Column(
                children: [
                  _PhotoAvatar(
                    photoUrl: user?.photoUrl,
                    name: user?.name ?? '',
                    isProvider: false,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'Utilisateur',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    user?.phone ?? '',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (user?.ratingCount ?? 0) > 0
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (user?.ratingCount ?? 0) > 0
                            ? '${(user?.rating ?? 0).toStringAsFixed(1)} · ${user?.ratingCount} avis prestataire(s)'
                            : 'Pas encore noté',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/user/edit-profile'),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Modifier mon profil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // VigiRoutes Client est 100% gratuit — plus d'abonnement.
            const _FreeAppBanner(),

            const SizedBox(height: 20),

            // Menu items
            _Section(
              title: 'Mon compte',
              items: [
                _MenuItem(
                  icon: Icons.directions_car_outlined,
                  label: 'Mes véhicules',
                  onTap: () => context.push('/user/vehicles'),
                ),
                _MenuItem(
                  icon: Icons.history,
                  label: 'Historique',
                  onTap: () => context.go('/user/history'),
                ),
                _MenuItem(
                  icon: Icons.star_border,
                  label: 'Mes avis',
                  onTap: () => context.push('/user/reviews'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _Section(
              title: 'Support',
              items: [
                _MenuItem(
                  icon: Icons.phone_outlined,
                  label: 'Appeler le support',
                  onTap: () => launchUrl(
                    Uri.parse('tel:${AppConstants.supportPhone}'),
                  ),
                ),
                _MenuItem(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp VigiRoutes',
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://wa.me/${AppConstants.supportWhatsapp.replaceAll('+', '')}',
                    ),
                  ),
                ),
                _MenuItem(
                  icon: Icons.help_outline,
                  label: 'FAQ',
                  onTap: () => context.push('/user/faq'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _Section(
              title: 'Légal',
              items: [
                _MenuItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Politique de confidentialité',
                  onTap: () => context.push('/user/privacy'),
                ),
                _MenuItem(
                  icon: Icons.article_outlined,
                  label: 'Conditions d\'utilisation',
                  onTap: () => launchUrl(
                    Uri.parse('https://vigiroutes.com/cgu'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) context.go('/onboarding');
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Se déconnecter',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// VigiRoutes Client est entièrement gratuit : liste complète des
/// prestataires, demandes illimitées, alerte SAMU/Pompiers — tout est
/// inclus sans abonnement. Cette bannière remplace l'ancienne carte
/// "Passer à Premium".
class _FreeAppBanner extends StatelessWidget {
  const _FreeAppBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.success, Color(0xFF0D7A47)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VigiRoutes est 100% gratuit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Tous les prestataires, demandes illimitées, alerte secours incluse',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isLast = i == items.length - 1;
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(item.icon, color: AppColors.primary),
                      title: Text(item.label),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textMuted),
                      onTap: item.onTap,
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 56, endIndent: 16),
                  ],
                );
              }),
            ),
          ),
        ],
      );
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});
}

class _PhotoAvatar extends StatefulWidget {
  final String? photoUrl;
  final String name;
  final bool isProvider;
  const _PhotoAvatar({this.photoUrl, required this.name, required this.isProvider});

  @override
  State<_PhotoAvatar> createState() => _PhotoAvatarState();
}

class _PhotoAvatarState extends State<_PhotoAvatar> {
  bool _loading   = false;
  int  _cacheKey  = 0; // incrémenté après chaque upload pour invalider le cache

  Future<void> _pickPhoto() async {
    final auth = context.read<AuthController>();
    if (auth.user?.id == null) return;

    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choisir dans la galerie'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;

    final XFile? file = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _loading = true);
    try {
      // Envoi RÉEL de l'image en multipart, puis rafraîchissement du profil.
      await ApiService.instance.uploadUserPhoto(file.path);
      if (mounted) await context.read<AuthController>().refreshUser();
      setState(() => _cacheKey = DateTime.now().millisecondsSinceEpoch);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo mise à jour ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lit directement depuis le controller pour se mettre à jour après refreshUser()
    final auth     = context.watch<AuthController>();
    final photoUrl = widget.isProvider
        ? null /* provider */?.photoUrl
        : auth.user?.photoUrl;
    final name   = widget.isProvider
        ? (null /* provider */?.name ?? widget.name)
        : (auth.user?.name   ?? widget.name);
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    // Cache-busting : timestamp changé à chaque rebuild post-upload
    final imageUrl = photoUrl != null
        ? '$photoUrl?v=$_cacheKey'
        : null;

    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: imageUrl != null
                ? NetworkImage(imageUrl)
                : null,
            child: imageUrl == null
                ? Text(letter,
                    style: const TextStyle(
                        fontSize: 32, color: AppColors.primary))
                : null,
          ),
          if (_loading)
            const Positioned.fill(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: Colors.black38,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
        ],
      ),
    );
  }
}
