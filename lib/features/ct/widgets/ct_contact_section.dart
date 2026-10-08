// lib/features/ct/widgets/ct_contact_section.dart
// ─────────────────────────────────────────────────────────────────────────────
// Section de contact du booking CT (S13.6).
// Affiche les boutons d'appel/WhatsApp vers le transporteur et le centre.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';

class CtContactSection extends StatelessWidget {
  final CtBookingModel booking;

  const CtContactSection({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    // Rien à afficher si ni transporteur ni centre ne sont joignables
    if (!booking.canContactTransporter && !booking.canContactCenter) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.contact_phone_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Contact',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Transporteur ─────────────────────────────────────────────
          if (booking.canContactTransporter) ...[
            _buildTransporterBlock(context),
            if (booking.canContactCenter) const SizedBox(height: 16),
          ],

          // ── Centre CT ────────────────────────────────────────────────
          if (booking.canContactCenter) _buildCenterBlock(context),
        ],
      ),
    );
  }

  Widget _buildTransporterBlock(BuildContext context) {
    final name = booking.transporterName ?? 'Transporteur';
    final type = booking.transporterType == 'tow'
        ? 'Remorquage'
        : booking.transporterType == 'driver'
            ? 'Chauffeur'
            : 'Transport';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_shipping_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Transporteur',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                type,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _call(context, booking.transporterPhone!),
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('Appeler'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _whatsapp(
                  context,
                  booking.transporterPhone!,
                  'Bonjour, je vous contacte au sujet de ma réservation ${booking.reference}.',
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCenterBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.business_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Centre CT',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${booking.center.name} — ${booking.center.city}',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _call(context, booking.center.contactPhone!),
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('Appeler'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _whatsapp(
                  context,
                  booking.center.contactPhone!,
                  'Bonjour, je vous contacte au sujet de ma réservation '
                      '${booking.reference} pour le véhicule '
                      '${booking.vehicle.registrationNumber}.',
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Lance un appel téléphonique.
  ///
  /// ⚠️ S13.6.1 : on n'utilise plus `canLaunchUrl()` (peu fiable sur Android).
  /// On tente directement `launchUrl()` et on affiche un feedback en cas
  /// d'échec (SnackBar), plutôt que de laisser le clic muet.
  Future<void> _call(BuildContext context, String phone) async {
    // Capture AVANT tout await (évite le warning use_build_context_synchronously)
    final messenger = ScaffoldMessenger.of(context);

    final cleaned = _normalizePhone(phone);
    if (cleaned.isEmpty) {
      _showSnack(messenger, 'Numéro invalide : $phone');
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _showSnack(messenger, 'Impossible de lancer l\'appel vers $cleaned');
      }
    } catch (e) {
      debugPrint('[CtContactSection] Erreur appel: $e');
      _showSnack(messenger, 'Erreur lors de l\'appel : $e');
    }
  }

  /// Ouvre WhatsApp avec un message pré-rempli.
  ///
  /// ⚠️ S13.6.1 : idem, `launchUrl()` direct + feedback en cas d'échec.
  Future<void> _whatsapp(
    BuildContext context,
    String phone,
    String message,
  ) async {
    // Capture AVANT tout await (évite le warning use_build_context_synchronously)
    final messenger = ScaffoldMessenger.of(context);

    final cleaned = _normalizePhone(phone, withPlus: false);
    if (cleaned.isEmpty) {
      _showSnack(messenger, 'Numéro invalide : $phone');
      return;
    }

    final uri = Uri.parse(
      'https://wa.me/$cleaned?text=${Uri.encodeComponent(message)}',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        _showSnack(messenger, 'Impossible d\'ouvrir WhatsApp');
      }
    } catch (e) {
      debugPrint('[CtContactSection] Erreur WhatsApp: $e');
      _showSnack(messenger, 'Erreur WhatsApp : $e');
    }
  }

  /// Normalise un numéro pour l'appel ou WhatsApp.
  ///
  /// - Retire tout sauf chiffres et +
  /// - Si le numéro local commence par 0 et fait 10 chiffres
  ///   → ajoute l'indicatif Côte d'Ivoire (+225 ou 225)
  /// - withPlus=true (défaut) : retourne "+225..."
  /// - withPlus=false : retourne "225..." (format wa.me)
  String _normalizePhone(String phone, {bool withPlus = true}) {
    var cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return '';

    // Retire le + en tête pour analyse
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);

    // Retire les 00 en tête
    if (cleaned.startsWith('00')) cleaned = cleaned.substring(2);

    // Format local CI (10 chiffres commençant par 0) → ajoute indicatif 225
    if (cleaned.length == 10 && cleaned.startsWith('0')) {
      cleaned = '225$cleaned';
    }

    return withPlus ? '+$cleaned' : cleaned;
  }

  void _showSnack(ScaffoldMessengerState messenger, String msg) {
    messenger.showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }
}
