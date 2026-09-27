// lib/features/ct/screens/ct_quote_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ct_quote_model.dart';
import '../../../core/models/tariff_model.dart';
import '../../../core/services/api_service.dart';
import '../controllers/ct_quote_controller.dart';

class CtQuoteDetailScreen extends StatefulWidget {
  final String requestId;
  const CtQuoteDetailScreen({super.key, required this.requestId});

  @override
  State<CtQuoteDetailScreen> createState() => _CtQuoteDetailScreenState();
}

class _CtQuoteDetailScreenState extends State<CtQuoteDetailScreen> {
  TariffModel? _tariff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<CtQuoteController>().loadRequest(widget.requestId);
      _loadTariff();
    });
  }

  Future<void> _loadTariff() async {
    try {
      final raw = await ApiService.instance.getTariffs();
      // Pour le CT on cherche le tarif global (service_type_slug null)
      // ou un tarif spécifique 'ct' s'il existe
      final list = raw
          .map((e) => TariffModel.fromJson(e as Map<String, dynamic>))
          .where((t) => t.isActive)
          .toList();

      TariffModel? found = list.cast<TariffModel?>().firstWhere(
        (t) => t?.serviceTypeSlug == 'ct',
        orElse: () => null,
      );
      found ??= list.cast<TariffModel?>().firstWhere(
        (t) => t?.serviceTypeSlug == null,
        orElse: () => null,
      );

      if (mounted) setState(() => _tariff = found);
    } catch (_) {}
  }

  Future<void> _respond(BuildContext context, String decision) async {
    final ctrl = context.read<CtQuoteController>();
    // Capture les références context-dépendantes AVANT tout await
    final router    = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          decision == 'accepted' ? 'Accepter le devis ?' : 'Refuser le devis ?',
          style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Text(
          decision == 'accepted'
              ? 'En acceptant, vous serez redirigé vers la prise de rendez-vous CT avec votre véhicule pré-sélectionné.'
              : 'Vous pouvez refuser et soumettre une nouvelle demande si nécessaire.',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: decision == 'accepted' ? AppColors.success : AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              decision == 'accepted' ? 'Accepter' : 'Refuser',
              style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    bool ok;
    if (decision == 'accepted') {
      ok = await ctrl.acceptQuote(widget.requestId);
    } else {
      ok = await ctrl.refuseQuote(widget.requestId);
    }

    if (!mounted) return;

    if (ok) {
      if (decision == 'accepted' && ctrl.bookingHint != null) {
        router.push(
          '/ct/booking',
          extra: {
            'booking_hint': {
              'vehicle_id':     ctrl.bookingHint!.vehicleId,
              'quote_id':       ctrl.bookingHint!.quoteId,
              'operator_ids':   ctrl.bookingHint!.operatorIds,
              'amount':         ctrl.bookingHint!.amount,
              'transport_mode': ctrl.bookingHint!.transportMode,
            },
          },
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Devis refusé.'), backgroundColor: AppColors.textSecondary),
        );
        router.pop();
      }
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(ctrl.respondError ?? 'Erreur'), backgroundColor: AppColors.error),
      );
    }
  }

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
          'Détail du devis',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.textPrimary),
        ),
      ),
      body: Consumer<CtQuoteController>(
        builder: (context, ctrl, _) {
          if (ctrl.isLoadingDetail) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (ctrl.detailError != null || ctrl.currentRequest == null) {
            return Center(
              child: Text(ctrl.detailError ?? 'Introuvable', style: const TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary)),
            );
          }
          final req = ctrl.currentRequest!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Statut ────────────────────────────────────────────────────
                _StatusBanner(status: req.status),
                const SizedBox(height: 20),

                // ── Infos demande ─────────────────────────────────────────────
                _Card(
                  title: 'Votre demande',
                  children: [
                    _InfoRow(label: 'Réf.', value: req.id.substring(0, 8).toUpperCase()),
                    _InfoRow(label: 'Transport', value: _transportLabel(req.transportMode)),
                    if (req.notes != null && req.notes!.isNotEmpty)
                      _InfoRow(label: 'Notes', value: req.notes!),
                    _InfoRow(label: 'Date', value: _formatDate(req.createdAt)),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Devis reçu ────────────────────────────────────────────────
                if (req.quote != null) ...[
                  _QuoteSection(
                    quote: req.quote!,
                    transportMode: req.transportMode,
                    tariff: _tariff,
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Boutons action ────────────────────────────────────────────
                if (req.isQuoted && req.quote != null && req.quote!.canRespond) ...[
                  const SizedBox(height: 8),
                  _ActionButtons(
                    isLoading: ctrl.isResponding,
                    onAccept: () => _respond(context, 'accepted'),
                    onRefuse: () => _respond(context, 'refused'),
                  ),
                ],

                // ── Devis expiré ──────────────────────────────────────────────
                if (req.isQuoted && req.quote != null && req.quote!.isExpired)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.timer_off_rounded, color: AppColors.error, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ce devis a expiré. Vous pouvez soumettre une nouvelle demande.',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  String _transportLabel(String mode) => switch (mode) {
    'tow'    => '🚛 Avec dépanneuse',
    'driver' => '🧑‍✈️ Avec chauffeur',
    _        => '🚗 Par mes propres moyens',
  };

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label, icon, msg) = _style(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15, color: color)),
                Text(msg, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: color.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, String, IconData, String) _style(String s) => switch (s) {
    'pending'  => (AppColors.warning, 'En attente', Icons.schedule_rounded, 'Un conseiller prépare votre devis.'),
    'quoted'   => (AppColors.primary, 'Devis reçu', Icons.mark_email_read_rounded, 'Consultez et répondez à votre devis ci-dessous.'),
    'accepted' => (AppColors.success, 'Devis accepté', Icons.check_circle_rounded, 'Votre rendez-vous CT a été initié.'),
    'refused'  => (AppColors.error, 'Devis refusé', Icons.cancel_rounded, 'Vous avez refusé ce devis.'),
    'expired'  => (AppColors.textMuted, 'Devis expiré', Icons.timer_off_rounded, 'Ce devis n\'est plus valable.'),
    'booked'   => (AppColors.success, 'RDV confirmé', Icons.event_available_rounded, 'Votre rendez-vous CT est confirmé.'),
    _          => (AppColors.textMuted, s, Icons.help_outline_rounded, ''),
  };
}

/// Section devis avec détail complet des frais.
class _QuoteSection extends StatelessWidget {
  final CtQuoteModel quote;
  final String transportMode;
  final TariffModel? tariff;

  const _QuoteSection({
    required this.quote,
    required this.transportMode,
    this.tariff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Devis', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
              const Spacer(),
              if (quote.validUntil != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: quote.isExpired ? AppColors.error.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    quote.isExpired ? 'Expiré' : 'Valide jusqu\'au ${_fmtDate(quote.validUntil!)}',
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600,
                      color: quote.isExpired ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),

          // ── Détail des frais ──────────────────────────────────────────────
          _buildBreakdown(),

          // Montant total mis en avant
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Montant total', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                Text(
                  '${_fmtAmount(quote.finalAmount)} FCFA',
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.primary),
                ),
              ],
            ),
          ),

          // Note admin
          if (quote.adminNotes != null && quote.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Note du conseiller', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(quote.adminNotes!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],

          // Centres CT proposés
          if (quote.operators.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Centres CT proposés', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ...quote.operators.map((op) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.store_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Text(op.operatorName ?? 'Opérateur #${op.operatorId}',
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textPrimary)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakdown() {
    // Priorité 1 : le backend a renvoyé le détail dans le devis
    if (quote.hasBreakdown) {
      final optionLabel = switch (transportMode) {
        'tow'    => 'Option Remorquage',
        'driver' => 'Option Chauffeur affecté',
        _        => 'Option Déplacement autonome',
      };
      return Column(children: [
        _FraisLine(label: 'Frais partenaire',      amount: quote.partnerAmount!),
        _FraisLine(label: optionLabel,              amount: quote.optionAmount!),
        _FraisLine(label: 'Frais service VigiRoutes', amount: quote.digitalFeeAmount!),
        const Divider(height: 16),
      ]);
    }

    // Priorité 2 : tarif configuré dans l'app (depuis /tariffs)
    if (tariff != null) {
      final fraisOption = tariff!.fraisOptionPour(transportMode);
      final optionLabel = switch (transportMode) {
        'tow'    => 'Option Remorquage',
        'driver' => 'Option Chauffeur affecté',
        _        => 'Option Déplacement autonome',
      };
      // Le base_amount du devis = frais partenaire
      return Column(children: [
        _FraisLine(label: 'Frais partenaire',         amount: quote.baseAmount),
        _FraisLine(label: optionLabel,                 amount: fraisOption),
        _FraisLine(label: 'Frais service VigiRoutes', amount: tariff!.fraisVigiRoutes),
        const Divider(height: 16),
      ]);
    }

    // Priorité 3 : aucun tarif — affichage simplifié
    if (quote.baseAmount != quote.finalAmount) {
      return Column(children: [
        _FraisLine(label: 'Montant de base', amount: quote.baseAmount),
        const Divider(height: 16),
      ]);
    }

    return const SizedBox.shrink();
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtAmount(int a) {
    final s = a.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _FraisLine extends StatelessWidget {
  final String label;
  final int amount;
  const _FraisLine({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    final s = amount.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary)),
        ),
        Text('$buf FCFA',
            style: const TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary)),
      ]),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  const _ActionButtons({required this.isLoading, required this.onAccept, required this.onRefuse});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onRefuse,
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
            label: const Text('Refuser', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, color: AppColors.error)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onAccept,
            icon: isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
            label: const Text('Accepter & prendre RDV', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
            const Divider(height: 20),
            ...children,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.textPrimary)),
            ),
          ],
        ),
      );
}
