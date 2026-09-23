import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/api_service.dart';
import '../controllers/ct_quote_controller.dart';

class CtQuoteNewScreen extends StatefulWidget {
  /// Pré-sélectionner un partenaire CT si on arrive depuis sa fiche.
  final String? preselectedProviderId;
  final String? preselectedProviderName;

  const CtQuoteNewScreen({
    super.key,
    this.preselectedProviderId,
    this.preselectedProviderName,
  });

  @override
  State<CtQuoteNewScreen> createState() => _CtQuoteNewScreenState();
}

class _CtQuoteNewScreenState extends State<CtQuoteNewScreen> {
  // ── Véhicules ───────────────────────────────────────────────────────────────
  List<VehicleModel> _vehicles = [];
  bool _loadingVehicles = true;
  VehicleModel? _selectedVehicle;

  // ── Partenaires CT ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _providers = [];
  bool _loadingProviders = true;
  String? _selectedProviderId;
  String? _selectedProviderName;

  // ── Autres champs ────────────────────────────────────────────────────────────
  String _transportMode = 'self';
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedProviderId = widget.preselectedProviderId;
    _selectedProviderName = widget.preselectedProviderName;
    _loadVehicles();
    _loadProviders();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final res = await ApiService.instance.get('/vehicles');
      final data = res.data['data'] as List<dynamic>;
      setState(() {
        _vehicles = data
            .map((e) => VehicleModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingVehicles = false;
        if (_vehicles.length == 1) _selectedVehicle = _vehicles.first;
      });
    } catch (_) {
      setState(() => _loadingVehicles = false);
    }
  }

  Future<void> _loadProviders() async {
    try {
      final res = await ApiService.instance.get('/ct/centers');
      final data = res.data['data'] as List<dynamic>;
      setState(() {
        _providers = data.map((e) => e as Map<String, dynamic>).toList();
        _loadingProviders = false;
        // Si pré-sélectionné, vérifier qu'il est dans la liste
        if (_selectedProviderId != null && _providers.isNotEmpty) {
          final found = _providers.any((p) => p['id'].toString() == _selectedProviderId);
          if (!found) {
            _selectedProviderId = null;
            _selectedProviderName = null;
          }
        }
      });
    } catch (_) {
      setState(() => _loadingProviders = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedVehicle == null) {
      _showError('Sélectionnez un véhicule');
      return;
    }
    if (_selectedProviderId == null) {
      _showError('Sélectionnez un centre de contrôle technique');
      return;
    }
    final ctrl = context.read<CtQuoteController>();
    final ok = await ctrl.submitRequest(
      vehicleId: _selectedVehicle!.id,
      providerId: _selectedProviderId!,
      transportMode: _transportMode,
      notes: _notesController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demande envoyée ! Vous recevrez un devis sous peu.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } else {
      _showError(ctrl.submitError ?? 'Erreur lors de l\'envoi');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loadingVehicles || _loadingProviders;

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
          'Demande de devis CT',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info banner ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Un conseiller vous enverra un devis personnalisé selon le centre choisi. Vous pourrez l\'accepter ou le refuser.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.primary.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Centre CT ────────────────────────────────────────────
                  const _SectionLabel(label: 'Centre de contrôle technique'),
                  const SizedBox(height: 10),
                  if (_providers.isEmpty)
                    _EmptyState(message: 'Aucun centre disponible dans votre ville.')
                  else
                    ..._providers.map((p) {
                      final id = p['id'].toString();
                      final name = p['name'] as String? ?? 'Centre CT';
                      final city = p['city'] as String?;
                      final isSelected = _selectedProviderId == id;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedProviderId = id;
                          _selectedProviderName = name;
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.car_repair_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (city != null)
                                      Text(
                                        city,
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // ── Véhicule ─────────────────────────────────────────────
                  const _SectionLabel(label: 'Votre véhicule'),
                  const SizedBox(height: 10),
                  if (_vehicles.isEmpty)
                    _EmptyState(message: 'Aucun véhicule enregistré. Ajoutez-en un dans votre profil.')
                  else
                    ..._vehicles.map((v) => _VehicleOption(
                          vehicle: v,
                          isSelected: _selectedVehicle?.id == v.id,
                          onTap: () => setState(() => _selectedVehicle = v),
                        )),

                  const SizedBox(height: 24),

                  // ── Mode transport ───────────────────────────────────────
                  const _SectionLabel(label: 'Mode de transport'),
                  const SizedBox(height: 10),
                  _TransportModeSelector(
                    value: _transportMode,
                    onChange: (v) => setState(() => _transportMode = v),
                  ),

                  const SizedBox(height: 24),

                  // ── Notes ────────────────────────────────────────────────
                  const _SectionLabel(label: 'Notes (optionnel)'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Informations supplémentaires pour le conseiller...',
                        hintStyle: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Bouton submit ────────────────────────────────────────
                  Consumer<CtQuoteController>(
                    builder: (_, ctrl, __) => SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (ctrl.isSubmitting || _vehicles.isEmpty || _providers.isEmpty)
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: ctrl.isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Envoyer la demande',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

class _VehicleOption extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleOption({required this.vehicle, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.brand} ${vehicle.model}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    vehicle.registrationNumber,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _TransportModeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;

  const _TransportModeSelector({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    const modes = [
      ('self', '🚗', 'Par mes propres moyens', 'Je conduis mon véhicule'),
      ('tow', '🚛', 'Dépanneuse', 'Mon véhicule sera remorqué'),
      ('driver', '🧑‍✈️', 'Avec chauffeur', 'Un chauffeur vient le chercher'),
    ];
    return Column(
      children: modes.map((m) {
        final isSelected = value == m.$1;
        return GestureDetector(
          onTap: () => onChange(m.$1),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Text(m.$2, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.$3,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        m.$4,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
