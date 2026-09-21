import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/ct_service.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'confirmed':
      case 'completed': return AppColors.success;
      case 'cancelled': return AppColors.error;
      default: return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'confirmed': return 'Confirmé';
      case 'completed': return 'Terminé';
      case 'cancelled': return 'Annulé';
      default: return status;
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
    final navigator  = Navigator.of(context);
    final messenger  = ScaffoldMessenger.of(context);

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
      if (mounted) navigator.pop();
    } catch (e) {
      setState(() => _cancelling = false);
      if (mounted) {
        messenger.showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
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
