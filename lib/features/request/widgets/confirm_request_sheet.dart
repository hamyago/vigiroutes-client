// lib/features/request/widgets/confirm_request_sheet.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet de confirmation d'une demande de dépannage (S15.2).
//
// Permet à l'utilisateur de :
//   - Voir un récapitulatif de sa demande (service, position, prix)
//   - Sélectionner le véhicule concerné (optionnel)
//   - Confirmer l'envoi
//
// Si l'utilisateur n'a qu'un seul véhicule, il est auto-sélectionné.
// Si aucun véhicule, la section est masquée.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../controllers/request_controller.dart';

class ConfirmRequestSheet extends StatefulWidget {
  final RequestController ctrl;
  final String? Function() formatPrice;   // formatage FCFA
  final Future<void> Function() onConfirm;

  const ConfirmRequestSheet({
    super.key,
    required this.ctrl,
    required this.formatPrice,
    required this.onConfirm,
  });

  /// Affiche le sheet. Retourne true si l'utilisateur a confirmé.
  static Future<bool> show({
    required BuildContext context,
    required RequestController ctrl,
    required String? Function() formatPrice,
    required Future<void> Function() onConfirm,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmRequestSheet(
        ctrl: ctrl,
        formatPrice: formatPrice,
        onConfirm: onConfirm,
      ),
    );
    return result ?? false;
  }

  @override
  State<ConfirmRequestSheet> createState() => _ConfirmRequestSheetState();
}

class _ConfirmRequestSheetState extends State<ConfirmRequestSheet> {
  List<VehicleModel> _vehicles = [];
  String? _selectedVehicleId;
  bool _loadingVehicles = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.ctrl.selectedVehicleId;
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    try {
      final raw = await ApiService.instance.getVehicles();
      final list = raw
          .map((e) {
            try { return VehicleModel.fromJson(e as Map<String, dynamic>); }
            catch (_) { return null; }
          })
          .whereType<VehicleModel>()
          .toList();

      if (!mounted) return;
      setState(() {
        _vehicles = list;
        // Auto-sélection si un seul véhicule (Q1=A)
        if (list.length == 1 && _selectedVehicleId == null) {
          _selectedVehicleId = list.first.id;
        }
        _loadingVehicles = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingVehicles = false);
    }
  }

  Future<void> _handleConfirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    // Propager la sélection au controller
    widget.ctrl.setVehicleId(_selectedVehicleId);

    // Exécuter l'action passée par l'appelant
    await widget.onConfirm();

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Confirmer la demande',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Récap
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildRecap(ctrl),
            ),

            // Sélecteur véhicule
            if (!_loadingVehicles && _vehicles.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildVehicleSelector(),
              ),
            ],

            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Confirmer l\'envoi',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecap(RequestController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _recapRow(Icons.build_rounded, ctrl.selectedService?.name ?? '—'),
        const SizedBox(height: 8),
        _recapRow(Icons.location_on_rounded, ctrl.userAddress ?? 'Position GPS'),
        if (ctrl.estimate != null) ...[
          const SizedBox(height: 8),
          _recapRow(
            Icons.payments_rounded,
            widget.formatPrice() ?? '—',
            highlight: true,
          ),
        ],
      ],
    );
  }

  Widget _recapRow(IconData icon, String text, {bool highlight = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: highlight ? 16 : 14,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleSelector() {
    // Si un seul véhicule → pas d'option "Non précisé" (Q1=A)
    final showNoneOption = _vehicles.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VÉHICULE CONCERNÉ (optionnel)',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ..._vehicles.map((v) => _vehicleTile(v)),
        if (showNoneOption) _noneTile(),
      ],
    );
  }

  Widget _vehicleTile(VehicleModel v) {
    final selected = _selectedVehicleId == v.id;
    return InkWell(
      onTap: () => setState(() => _selectedVehicleId = v.id),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.plate,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${v.brand} ${v.model}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _noneTile() {
    final selected = _selectedVehicleId == null;
    return InkWell(
      onTap: () => setState(() => _selectedVehicleId = null),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Non précisé',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
