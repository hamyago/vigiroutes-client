import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../features/legal/screens/privacy_policy_screen.dart';

/// Case à cocher « J'accepte les CGU » + accès à la Politique de confidentialité.
/// Bloque l'inscription tant que la case n'est pas cochée.
class CguCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const CguCheckbox({super.key, required this.value, required this.onChanged});

  Future<void> _openCgu(BuildContext context) async {
    final uri = Uri.parse('https://vigiroutes.com/cgu');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir la page.')),
        );
      }
    }
  }

  void _openPrivacy(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                activeColor: AppColors.primary,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  children: [
                    const Text("J'ai lu et j'accepte les ",
                        style: TextStyle(fontSize: 13)),
                    GestureDetector(
                      onTap: () => _openCgu(context),
                      child: const Text(
                        "Conditions d'utilisation",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: GestureDetector(
            onTap: () => _openPrivacy(context),
            child: const Text(
              'Politique de confidentialité',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
