import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/ct_quote_model.dart';
import '../controllers/ct_quote_controller.dart';

class CtQuoteDetailScreen extends StatefulWidget {
  final String requestId;
  const CtQuoteDetailScreen({super.key, required this.requestId});

  @override
  State<CtQuoteDetailScreen> createState() => _CtQuoteDetailScreenState();
}

class _CtQuoteDetailScreenState extends State<CtQuoteDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CtQuoteController>().loadRequest(widget.requestId);
    });
  }

  Future<void> _respond(BuildContext context, String decision) async {
    final ctrl = context.read<CtQuoteController>();
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
        // Lancer le flux CT avec hint pré-rempli
        context.push(
          '/ct/booking',
          extra: {'booking_hint': ctrl.bookingHint},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devis refusé.'), backgroundColor: AppColors.textSecondary),
        );
        context.pop();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
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
                    _Row(label: 'Réf.', value: req.id.substring(0, 8).toUpperCase()),
                    _Row(label: 'Transport', value: _transportLabel(req.transportMode)),
                    if (req.notes != null && req.notes!.isNotEmpty)
                      _Row(label: 'Notes', value: req.notes!),
                    _Row(label: 'Date', value: _formatDate(req.createdAt)),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Devis reçu ────────────────────────────────────────────────
                if (req.quote != null) ...[
                  _QuoteSection(quote: req.quote!),
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

class _QuoteSection extends StatelessWidget {
  final CtQuoteModel quote;
  const _QuoteSection({required this.quote});

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

          // Montant final mis en avant
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

          if (quote.baseAmount != quote.finalAmount) ...[
            const SizedBox(height: 10),
            _Row(label: 'Montant de base', value: '${_fmtAmount(quote.baseAmount)} FCFA'),
          ],

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

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String _fmtAmount(int a) {
    final s = a.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return buf.toString();
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

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

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
