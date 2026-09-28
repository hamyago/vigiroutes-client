// lib/features/ct/screens/ct_entry_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Écran d'entrée pour le module Contrôle Technique.
//
// Rôle : orienter l'utilisateur vers le bon parcours :
//   - Demander un devis (nouveau client, ou nouveau véhicule)
//   - Consulter ses devis existants (client qui a déjà une demande)
//
// ⚠️ Pas d'accès direct au flow de booking sans devis accepté.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';

class CtEntryScreen extends StatelessWidget {
  const CtEntryScreen({super.key});

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
          'Contrôle technique',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF1565C0),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le tarif du contrôle technique dépend du centre partenaire '
                      'choisi. Demandez un devis pour connaître le montant exact.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        height: 1.4,
                        color: const Color(0xFF1565C0).withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _EntryCard(
              icon: Icons.request_quote_outlined,
              iconColor: AppColors.primary,
              title: 'Demander un devis',
              subtitle:
                  'Décrivez votre besoin, choisissez un centre partenaire '
                  'et recevez un devis personnalisé.',
              actionLabel: 'Demander un devis',
              onTap: () => context.push('/ct/quote/new'),
              primary: true,
            ),
            const SizedBox(height: 16),
            _EntryCard(
              icon: Icons.receipt_long_outlined,
              iconColor: AppColors.textSecondary,
              title: 'Mes demandes de devis',
              subtitle:
                  'Consultez vos demandes en cours et vos devis reçus. '
                  'Acceptez un devis pour prendre rendez-vous.',
              actionLabel: 'Voir mes demandes',
              onTap: () => context.push('/ct/quotes'),
              primary: false,
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Besoin d\'aide ?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () => context.push('/user/faq'),
                icon: const Icon(Icons.help_outline_rounded,
                    size: 18, color: AppColors.primary),
                label: const Text(
                  'Consulter la FAQ',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  final bool primary;

  const _EntryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary ? AppColors.primary : AppColors.border,
            width: primary ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  actionLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: primary ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: primary ? AppColors.primary : AppColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
