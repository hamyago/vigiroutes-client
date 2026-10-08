import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/ct_service.dart';
import '../widgets/transport_timeline.dart';
import '../widgets/ct_contact_section.dart';
import '../widgets/vehicle_photos_section.dart';

class CtBookingDetailScreen extends StatefulWidget {
  final String bookingId;
  const CtBookingDetailScreen({super.key, required this.bookingId});

  @override
  State<CtBookingDetailScreen> createState() => _CtBookingDetailScreenState();
}

class _CtBookingDetailScreenState extends State<CtBookingDetailScreen> {
  CtBookingModel? _booking;
  bool _loading = true;
  String? _error;
  bool _cancelling = false;
  bool _isRegeneratingQr = false;

  /// ⏱️ Timer de rafraîchissement automatique (S13.6.2).
  /// Recharge le booking toutes les 15s tant qu'il n'est pas terminé.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  /// Démarre le polling de rafraîchissement (S13.6.2).
  void _startPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final b = _booking;
      if (b == null) return;
      // On arrête le polling si le booking est terminé ou annulé
      if (b.isCompleted || b.isCancelled) {
        _stopPolling();
        return;
      }
      _refreshSilently();
    });
  }

  /// Arrête le polling.
  void _stopPolling() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Recharge le booking sans afficher le loader (rafraîchissement discret).
  Future<void> _refreshSilently() async {
    try {
      final b = await CtService.instance.getBooking(widget.bookingId);
      if (!mounted) return;
      setState(() => _booking = b);
      // Si le booking est maintenant terminé/annulé, on stoppe
      if (b.isCompleted || b.isCancelled) _stopPolling();
    } catch (_) {
      // Erreur silencieuse : on retente au prochain tick
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final b = await CtService.instance.getBooking(widget.bookingId);
      setState(() { _booking = b; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Regénère le QR code du booking et rafraîchit l'écran.
  Future<void> _onRegenerateQr() async {
    if (_isRegeneratingQr) return;
    setState(() => _isRegeneratingQr = true);

    try {
      // 1. Appel API : regénère le token
      await CtService.instance.regenerateQr(widget.bookingId);

      // 2. Recharge le booking pour avoir le nouveau qr_token + qr_expires_at
      final fresh = await CtService.instance.getBooking(widget.bookingId);

      if (!mounted) return;
      setState(() {
        _booking = fresh;
        _isRegeneratingQr = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ QR code regénéré avec succès'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegeneratingQr = false);

      // Message backend prioritaire
      String message = 'Erreur lors de la régénération';
      final errStr = e.toString();
      if (errStr.contains('429')) {
        message = 'Limite de regénérations atteinte. Contactez le centre.';
      } else if (errStr.contains('409')) {
        message = 'Impossible de regénérer : cette réservation est terminée.';
      } else if (errStr.contains('422')) {
        message = 'Paiement requis avant de générer le QR.';
      } else if (errStr.contains('404')) {
        message = 'Réservation introuvable.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Message contextuel selon le mode de transport.
  /// Le QR est présenté différemment selon qui amène le véhicule au centre.
  String _qrHintForTransport(String mode) {
    switch (mode) {
      case 'tow':
        return 'Votre dépanneur va scanner ce QR code lors de la prise en charge du véhicule. '
               'Vous pouvez aussi lui partager cette image par WhatsApp ou SMS.';
      case 'driver':
        return 'Votre chauffeur va scanner ce QR code lors de la prise en charge du véhicule. '
               'Vous pouvez aussi lui partager cette image par WhatsApp ou SMS.';
      default:
        return 'Présentez ce QR code à l\'agent du centre le jour de votre rendez-vous.';
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':     return AppColors.warning;
      case 'confirmed':   return AppColors.primary;
      case 'arrived':     return Colors.blue;
      case 'in_progress': return Colors.amber.shade700;
      case 'completed':   return AppColors.success;
      case 'cancelled':   return AppColors.error;
      default:            return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':      return 'En attente';
      case 'confirmed':    return 'Confirmé';
      case 'arrived':      return 'Arrivé au centre';
      case 'in_progress':  return 'Contrôle en cours';
      case 'completed':    return 'Terminé';
      case 'cancelled':    return 'Annulé';
      default:             return status;
    }
  }

  String _transportLabel(String mode) {
    switch (mode) {
      case 'self': return 'Véhicule personnel';
      case 'tow': return 'Remorquage';
      case 'driver': return 'Chauffeur';
      default: return mode;
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler le rendez-vous'),
        content: const Text('Voulez-vous vraiment annuler ce rendez-vous ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _cancelling = true);
    try {
      await CtService.instance.cancelBooking(widget.bookingId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _cancelling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Intercepte le bouton retour natif Android.
    // Sans ça, `go()` ayant remplacé la pile, le retour sort de l'app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/ct/bookings');
        }
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/ct/bookings');
            }
          },
        ),
        title: const Text('Détail du rendez-vous',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final b = _booking!;
    final canCancel = b.status == 'pending' || b.status == 'confirmed';
    final statusColor = _statusColor(b.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Status badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: statusColor.withAlpha(80)),
            ),
            child: Text(_statusLabel(b.status),
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 20),

        // Infos réservation
        _Section(title: 'Réservation', children: [
          _InfoRow(label: 'Référence', value: b.reference),
          _InfoRow(label: 'Date du créneau', value: _formatDate(b.slotStartsAt)),
          _InfoRow(label: 'Mode de transport', value: _transportLabel(b.transportMode)),
          _InfoRow(label: 'Paiement', value: b.paymentStatus),
          _InfoRow(label: 'Montant total', value: '${b.totalAmount.toStringAsFixed(0)} FCFA'),
        ]),
        const SizedBox(height: 16),

        // Véhicule
        _Section(title: 'Véhicule', children: [
          _InfoRow(label: 'Immatriculation', value: b.vehicle.registrationNumber),
          _InfoRow(label: 'Marque', value: b.vehicle.brand),
          _InfoRow(label: 'Modèle', value: b.vehicle.model),
          if (b.vehicle.color != null)
            _InfoRow(label: 'Couleur', value: b.vehicle.color!),
        ]),
        const SizedBox(height: 16),

        // Centre
        _Section(title: 'Centre CT', children: [
          _InfoRow(label: 'Nom', value: b.center.name),
          _InfoRow(label: 'Ville', value: b.center.city),
          if (b.center.address != null)
            _InfoRow(label: 'Adresse', value: b.center.address!),
          if (b.center.contactPhone != null)
            _InfoRow(label: 'Téléphone', value: b.center.contactPhone!),
        ]),
        const SizedBox(height: 16),

        // ── Section Contact (S13.6) ──────────────────────────────────
        CtContactSection(booking: b),
        const SizedBox(height: 16),

        // ── Suivi du transport (si tow/driver) ────────────────────────
        if (b.hasTransportTracking) ...[
          TransportTimeline(booking: b),
          const SizedBox(height: 16),
        ],

        // ── Photos du véhicule (S16.2) ────────────────────────────────
        VehiclePhotosSection(
          bookingId: b.id,
          transporterStatus: b.transporterStatus,
        ),
        const SizedBox(height: 16),

        // ── QR code conditionnel (Option D) ─────────────────────────────────
        // Le QR est affiché tant que le créneau est dans le futur OU
        // dans les 24h qui suivent. Après, il est masqué (contrôle effectué).
        if (b.qrToken != null) ...[
          Builder(builder: (context) {
            // ✅ Aligné sur la logique backend : on utilise qrExpiresAt
            // au lieu de slotStartsAt + 24h. Évite la fenêtre de 12h
            // pendant laquelle le backend refuse le QR mais l'app
            // l'affiche encore.
            final isQrExpired = b.qrExpiresAt == null
                || b.qrExpiresAt!.isBefore(DateTime.now());

            if (isQrExpired) {
              return _Section(title: 'QR Code d\'entrée', children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.orange, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QR code expiré',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Votre QR code n\'est plus valide. Regénérez-en un nouveau pour vous présenter au centre.',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isRegeneratingQr ? null : _onRegenerateQr,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _isRegeneratingQr
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 18),
                          label: Text(
                            _isRegeneratingQr
                                ? 'Regénération…'
                                : 'Régénérer mon QR code',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]);
            }

            // QR valide → on l'affiche
            return _Section(title: 'QR Code d\'entrée', children: [
              Text(
                _qrHintForTransport(b.transportMode),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: QrImageView(
                    data: b.qrToken!,
                    version: QrVersions.auto,
                    size: 200,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  b.reference,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ]);
          }),
          const SizedBox(height: 16),
        ],

        // Résultat VT (si disponible)
        if (b.vtResult != null) ...[
          _Section(title: 'Résultat CT', children: [
            _InfoRow(label: 'Résultat', value: b.vtResult!),
            if (b.vtReportNotes != null)
              _InfoRow(label: 'Observations', value: b.vtReportNotes!),
            if (b.nextVtDueDate != null)
              _InfoRow(label: 'Prochain CT', value: _formatDate(b.nextVtDueDate!)),
          ]),
          const SizedBox(height: 16),
        ],

        if (canCancel)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancelling ? null : _cancel,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _cancelling
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(color: AppColors.error, strokeWidth: 2))
                  : const Text('Annuler le rendez-vous',
                      style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 140,
          child: Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
