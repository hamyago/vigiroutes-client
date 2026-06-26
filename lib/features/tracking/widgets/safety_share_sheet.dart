import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/models.dart';
import '../../../core/services/safety_share_service.dart';
import '../../../core/constants/app_colors.dart';

/// Bottom sheet permettant à l'utilisateur de partager
/// sa position GPS + infos prestataire à un proche par SMS.
///
/// Usage :
/// ```dart
/// SafetyShareSheet.show(context, intervention: _intervention);
/// ```
class SafetyShareSheet extends StatefulWidget {
  final InterventionModel intervention;
  const SafetyShareSheet({super.key, required this.intervention});

  static Future<void> show(
    BuildContext context, {
    required InterventionModel intervention,
  }) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SafetyShareSheet(intervention: intervention),
      );

  @override
  State<SafetyShareSheet> createState() => _SafetyShareSheetState();
}

class _SafetyShareSheetState extends State<SafetyShareSheet> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    final i = widget.intervention;

    final ok = await SafetyShareService.instance.sendSafetyMessage(
      phone: _phoneCtrl.text.trim(),
      latitude: i.userLatitude,
      longitude: i.userLongitude,
      providerName: i.providerName ?? 'Prestataire VigiRoutes',
      serviceType: i.serviceTypeName,
      etaMinutes: null, // ETA non disponible sans calcul d'itinéraire
    );

    setState(() {
      _isSending = false;
      if (ok) {
        _sent = true;
      } else {
        _error = "Impossible d'ouvrir l'application SMS.\n"
            "Vérifiez les permissions ou envoyez manuellement.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Titre
          const Row(
            children: [
              Text('🛡️', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Partager ma position',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  Text(
                    'Alerter un proche par SMS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Aperçu du message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Contenu du SMS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '🛡️ VigiRoutes — Alerte sécurité\n'
                  'Service : ${widget.intervention.serviceTypeName}\n'
                  '🔧 Prestataire : ${widget.intervention.providerName ?? "En attente..."}\n'
                  '📍 Ma position GPS (lien Google Maps)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // État succès
          if (_sent) ...[
            _SuccessView(
              onClose: () => Navigator.of(context).pop(),
            ),
          ] else ...[
            // Formulaire saisie numéro
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\+\s\-]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Numéro du proche',
                  hintText: 'Ex : 07 00 00 00 00',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  prefixText: '+225  ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 2),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Entrez un numéro de téléphone';
                  }
                  final digits =
                      v.replaceAll(RegExp(r'[\s\-\+\(\)]'), '');
                  if (digits.length < 8) {
                    return 'Numéro trop court';
                  }
                  return null;
                },
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 12),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Bouton envoyer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSending ? 'Ouverture SMS...' : 'Envoyer le SMS',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onClose;
  const _SuccessView({required this.onClose});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: const Column(
              children: [
                Text('✅', style: TextStyle(fontSize: 36)),
                SizedBox(height: 8),
                Text(
                  'SMS prêt à envoyer !',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.success,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "L'application SMS s'est ouverte avec le message "
                  "pré-rempli. Appuyez sur Envoyer dans votre SMS.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Retour au suivi",
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
}
