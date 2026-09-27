import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/vehicle_model.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';

// ─── Constantes ───────────────────────────────────────────────────────────────

const _categories = ['VP', 'VU', 'Moto', 'Camion', 'Bus'];
const _categoryLabels = {
  'VP': 'Voiture particulière (VP)',
  'VU': 'Véhicule utilitaire (VU)',
  'Moto': 'Moto / Tricycle',
  'Camion': 'Camion / Poids lourd',
  'Bus': 'Bus / Minibus',
};

const _energies = ['essence', 'gasoil', 'hybride', 'electrique'];
const _energyLabels = {
  'essence': 'Essence',
  'gasoil': 'Gasoil / Diesel',
  'hybride': 'Hybride',
  'electrique': 'Électrique',
};

const _usages = ['privée', 'public'];
const _usageLabels = {
  'privée': 'Usage privé',
  'public': 'Usage commercial / public',
};

// ─── Écran principal ──────────────────────────────────────────────────────────

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<VehicleModel> _vehicles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fallbackVehicles =
        context.read<AuthController>().user?.vehicles ?? [];

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.instance.getVehicles();
      _vehicles = raw
          .map((v) {
            try {
              return VehicleModel.fromJson(v as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<VehicleModel>()
          .toList();
    } catch (e) {
      final embedded = fallbackVehicles
          .map((v) {
            try {
              return VehicleModel.fromJson(v as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<VehicleModel>()
          .toList();
      _vehicles = embedded;
      _error = embedded.isEmpty ? 'Impossible de charger les véhicules : $e' : null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(String id, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce véhicule ?'),
        content: Text(
          'Voulez-vous supprimer "$label" ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) await _delete(id);
  }

  Future<void> _delete(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    try {
      await ApiService.instance.deleteVehicle(id);
      await _load();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        content: Text('Véhicule supprimé'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      final msg = _readableError(e);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  String _readableError(Object e) {
    final raw = e.toString();
    if (raw.contains('422')) {
      return 'Données invalides. Vérifiez les champs obligatoires (catégorie, usage, énergie, puissance).';
    }
    if (raw.contains('500') || raw.contains('Internal Server Error')) {
      return 'Erreur serveur. Vérifiez que le véhicule n\'a pas de réservation active.';
    }
    if (raw.contains('404')) return 'Véhicule introuvable.';
    if (raw.contains('403') || raw.contains('unauthorized')) {
      return 'Vous n\'êtes pas autorisé à effectuer cette action.';
    }
    if (raw.contains('SocketException') || raw.contains('connection')) {
      return 'Pas de connexion internet. Réessayez.';
    }
    return 'Une erreur est survenue. Réessayez.';
  }

  Future<void> _showAddVehicle() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _VehicleSheet(),
    );
    if (added == true) await _load();
  }

  Future<void> _showEditVehicle(VehicleModel v) async {
    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VehicleSheet(vehicle: v),
    );
    if (edited == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes véhicules')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicle,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _vehicles.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      const Center(
                        child: Column(children: [
                          Text('🚗', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('Aucun véhicule enregistré',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.error, fontSize: 12)),
                        ),
                      ],
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _vehicles.length,
                    itemBuilder: (_, i) {
                      final v = _vehicles[i];
                      final label = '${v.brand} ${v.model} ${v.registrationNumber}'.trim();
                      return _VehicleTile(
                        vehicle: v,
                        onEdit: () => _showEditVehicle(v),
                        onDelete: () => _confirmDelete(v.id, label),
                      );
                    },
                  ),
      ),
    );
  }
}

// ─── Tuile véhicule ──────────────────────────────────────────────────────────

class _VehicleTile extends StatelessWidget {
  final VehicleModel vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _VehicleTile({required this.vehicle, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight, shape: BoxShape.circle),
                  child: const Center(
                      child: Text('🚗', style: TextStyle(fontSize: 24)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${vehicle.brand} ${vehicle.model}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(vehicle.registrationNumber,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    Row(children: [
                      if (vehicle.color != null)
                        Text('${vehicle.color!}  ',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      if (vehicle.year != null)
                        Text('${vehicle.year}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                    ]),
                  ])),
              IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  tooltip: 'Modifier',
                  onPressed: onEdit),
              IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Supprimer',
                  onPressed: onDelete),
            ]),
            // Infos techniques
            if (vehicle.category.isNotEmpty || vehicle.usage != null || vehicle.puissanceCv != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (vehicle.category.isNotEmpty)
                    _InfoChip(label: _categoryLabels[vehicle.category] ?? vehicle.category, icon: Icons.category_outlined),
                  if (vehicle.usage != null)
                    _InfoChip(label: _usageLabels[vehicle.usage] ?? vehicle.usage!, icon: Icons.badge_outlined),
                  if (vehicle.energy != null)
                    _InfoChip(label: _energyLabels[vehicle.energy] ?? vehicle.energy!, icon: Icons.local_gas_station_outlined),
                  if (vehicle.puissanceCv != null)
                    _InfoChip(label: '${vehicle.puissanceCv} CV', icon: Icons.speed_outlined),
                ],
              ),
            ],
            const SizedBox(height: 10),
            // Badges CT / Assurance / Vignette
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ExpiryBadge(
                  icon: Icons.verified_outlined,
                  label: 'CT',
                  date: vehicle.technicalVisitExpiresAt,
                ),
                _ExpiryBadge(
                  icon: Icons.shield_outlined,
                  label: 'Assurance',
                  date: vehicle.insuranceExpiresAt,
                ),
                _ExpiryBadge(
                  icon: Icons.local_offer_outlined,
                  label: 'Vignette',
                  date: vehicle.vignetteExpiresAt,
                ),
              ],
            ),
          ],
        ),
      );
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary)),
        ]),
      );
}

class _ExpiryBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime? date;

  const _ExpiryBadge({
    required this.icon,
    required this.label,
    required this.date,
  });

  int? get _daysLeft =>
      date == null ? null : date!.difference(DateTime.now()).inDays;

  Color get _color {
    final d = _daysLeft;
    if (d == null) return Colors.grey.shade400;
    if (d < 0)   return AppColors.error;
    if (d <= 7)  return Colors.red.shade400;
    if (d <= 30) return Colors.orange.shade500;
    return Colors.green.shade500;
  }

  String get _text {
    final d = _daysLeft;
    if (d == null) return '$label : —';
    if (d < 0)    return '$label expiré (${-d}j)';
    if (d == 0)   return '$label : aujourd\'hui !';
    return '$label : ${DateFormat('dd/MM/yy').format(date!)} · ${d}j';
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withValues(alpha: 0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: _color),
          const SizedBox(width: 4),
          Text(_text,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _color)),
        ]),
      );
}

// ─── Widget sélecteur de date réutilisable ───────────────────────────────────

class _DatePicker extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String? hint;

  const _DatePicker({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    required this.onClear,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final borderColor = hasValue ? AppColors.primary : Colors.grey.shade400;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(10),
          color: hasValue
              ? AppColors.primary.withValues(alpha: 0.04)
              : Colors.transparent,
        ),
        child: Row(children: [
          Icon(icon, size: 18,
              color: hasValue ? AppColors.primary : Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: hasValue
                            ? AppColors.primary
                            : Colors.grey.shade500)),
                Text(
                  hasValue
                      ? DateFormat('dd/MM/yyyy').format(value!)
                      : 'Non renseigné',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          hasValue ? FontWeight.w600 : FontWeight.normal,
                      color: hasValue
                          ? AppColors.textPrimary
                          : Colors.grey.shade400),
                ),
                if (hasValue && hint != null)
                  Text(hint!,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (hasValue)
            GestureDetector(
              onTap: onClear,
              child:
                  Icon(Icons.close, size: 16, color: Colors.grey.shade400),
            )
          else
            Icon(Icons.calendar_today_outlined,
                size: 16, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

// ─── Formulaire ajout / édition ───────────────────────────────────────────────

class _VehicleSheet extends StatefulWidget {
  /// Si null → mode ajout. Sinon → mode édition.
  final VehicleModel? vehicle;
  const _VehicleSheet({this.vehicle});
  @override
  State<_VehicleSheet> createState() => _VehicleSheetState();
}

class _VehicleSheetState extends State<_VehicleSheet> {
  final _formKey        = GlobalKey<FormState>();
  final _brandCtrl      = TextEditingController();
  final _modelCtrl      = TextEditingController();
  final _plateCtrl      = TextEditingController();
  final _colorCtrl      = TextEditingController();
  final _yearCtrl       = TextEditingController();
  final _carteGriseCtrl = TextEditingController();
  final _puissanceCtrl  = TextEditingController();
  final _ptacCtrl       = TextEditingController();

  String? _category;
  String? _energy;
  String? _usage;

  DateTime? _ctExpiryDate;
  DateTime? _insuranceExpiryDate;
  DateTime? _vignetteExpiryDate;
  bool _loading = false;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) {
      _brandCtrl.text      = v.brand;
      _modelCtrl.text      = v.model;
      _plateCtrl.text      = v.registrationNumber;
      _colorCtrl.text      = v.color ?? '';
      _yearCtrl.text       = v.year?.toString() ?? '';
      _carteGriseCtrl.text = v.carteGriseNumber ?? '';
      _puissanceCtrl.text  = v.puissanceCv?.toString() ?? '';
      _category            = v.category.isEmpty ? null : v.category;
      _energy              = v.energy;
      _usage               = v.usage;
      _ctExpiryDate        = v.technicalVisitExpiresAt;
      _insuranceExpiryDate = v.insuranceExpiresAt;
      _vignetteExpiryDate  = v.vignetteExpiresAt;
    }
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    _carteGriseCtrl.dispose();
    _puissanceCtrl.dispose();
    _ptacCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> onPicked,
      {required String label}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
      helpText: label,
    );
    if (picked != null) onPicked(picked);
  }

  Map<String, dynamic> _buildPayload() => {
    'brand': _brandCtrl.text.trim(),
    'model': _modelCtrl.text.trim(),
    'registration_number': _plateCtrl.text.trim().toUpperCase(),
    'category': _category ?? 'VP',
    'usage': _usage ?? 'privée',
    if (_energy != null) 'energy': _energy,
    if (_colorCtrl.text.trim().isNotEmpty) 'color': _colorCtrl.text.trim(),
    if (_yearCtrl.text.trim().isNotEmpty)
      'year': int.tryParse(_yearCtrl.text.trim()),
    if (_carteGriseCtrl.text.trim().isNotEmpty)
      'carte_grise_number': _carteGriseCtrl.text.trim(),
    if (_puissanceCtrl.text.trim().isNotEmpty)
      'puissance_cv': int.tryParse(_puissanceCtrl.text.trim()),
    if (_ctExpiryDate != null)
      'technical_visit_expires_at':
          DateFormat('yyyy-MM-dd').format(_ctExpiryDate!),
    if (_insuranceExpiryDate != null)
      'insurance_expires_at':
          DateFormat('yyyy-MM-dd').format(_insuranceExpiryDate!),
    if (_vignetteExpiryDate != null)
      'vignette_expires_at':
          DateFormat('yyyy-MM-dd').format(_vignetteExpiryDate!),
  };

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      if (_isEdit) {
        await ApiService.instance.updateVehicle(widget.vehicle!.id, _buildPayload());
      } else {
        await ApiService.instance.addVehicle(_buildPayload());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEdit ? 'Véhicule mis à jour' : 'Véhicule ajouté'),
            backgroundColor: AppColors.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        final msg = raw.contains('422')
            ? 'Données invalides : vérifiez la catégorie, l\'usage et la puissance.'
            : 'Erreur : $e';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    bool required = false,
    IconData? icon,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: _dec(label, icon: icon),
      hint: Text('Sélectionner'),
      isExpanded: true,
      items: items
          .map((e) => DropdownMenuItem<T>(
                value: e,
                child: Text(itemLabel(e), overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
      validator: required
          ? (v) => v == null ? 'Champ requis' : null
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Hauteur max = 92 % de l'écran pour ne jamais dépasser
      constraints: BoxConstraints(maxHeight: screenH * 0.92),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zone scrollable qui pousse le clavier vers le haut
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
              child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Poignée
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(_isEdit ? 'Modifier le véhicule' : 'Ajouter un véhicule',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 20),

            // ── Marque ──
            TextFormField(
              controller: _brandCtrl,
              decoration: _dec('Marque *', hint: 'Toyota', icon: Icons.directions_car),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),

            // ── Modèle ──
            TextFormField(
              controller: _modelCtrl,
              decoration: _dec('Modèle', hint: 'Corolla', icon: Icons.drive_eta),
            ),
            const SizedBox(height: 12),

            // ── Immatriculation ──
            TextFormField(
              controller: _plateCtrl,
              decoration: _dec('Immatriculation *',
                  hint: 'AB 1234 CI', icon: Icons.pin),
              textCapitalization: TextCapitalization.characters,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),

            // ── Catégorie * ──
            _dropdownField<String>(
              label: 'Catégorie *',
              value: _category,
              items: _categories,
              itemLabel: (c) => _categoryLabels[c] ?? c,
              onChanged: (v) => setState(() => _category = v),
              required: true,
              icon: Icons.category_outlined,
            ),
            const SizedBox(height: 12),

            // ── Usage * ──
            _dropdownField<String>(
              label: 'Usage *',
              value: _usage,
              items: _usages,
              itemLabel: (u) => _usageLabels[u] ?? u,
              onChanged: (v) => setState(() => _usage = v),
              required: true,
              icon: Icons.badge_outlined,
            ),
            const SizedBox(height: 12),

            // ── Énergie ──
            _dropdownField<String>(
              label: 'Carburant / Énergie',
              value: _energy,
              items: _energies,
              itemLabel: (e) => _energyLabels[e] ?? e,
              onChanged: (v) => setState(() => _energy = v),
              icon: Icons.local_gas_station_outlined,
            ),
            const SizedBox(height: 12),

            // ── Puissance & Couleur sur la même ligne ──
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _puissanceCtrl,
                  decoration: _dec('Puissance (CV)', hint: '90', icon: Icons.speed_outlined),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (int.tryParse(v.trim()) == null) return 'Nombre entier';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _colorCtrl,
                  decoration: _dec('Couleur', hint: 'Blanc'),
                ),
              ),
            ]),
            const SizedBox(height: 12),

            // ── Année & Carte grise sur la même ligne ──
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _yearCtrl,
                  decoration: _dec('Année', hint: '2019'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final y = int.tryParse(v.trim());
                    if (y == null || y < 1950 || y > DateTime.now().year + 1) {
                      return 'Année invalide';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _carteGriseCtrl,
                  decoration: _dec('N° Carte grise', hint: 'CI-123456-A',
                      icon: Icons.article_outlined),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Dates de validité ──
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Dates de validité',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            const SizedBox(height: 8),

            _DatePicker(
              label: 'Contrôle technique',
              icon: Icons.verified_outlined,
              value: _ctExpiryDate,
              onTap: () => _pickDate(
                _ctExpiryDate,
                (d) => setState(() => _ctExpiryDate = d),
                label: 'Expiration CT',
              ),
              onClear: () => setState(() => _ctExpiryDate = null),
              hint: 'Rappel 7j, 3j et 1j avant expiration',
            ),
            const SizedBox(height: 8),

            _DatePicker(
              label: 'Assurance',
              icon: Icons.shield_outlined,
              value: _insuranceExpiryDate,
              onTap: () => _pickDate(
                _insuranceExpiryDate,
                (d) => setState(() => _insuranceExpiryDate = d),
                label: 'Expiration assurance',
              ),
              onClear: () => setState(() => _insuranceExpiryDate = null),
            ),
            const SizedBox(height: 8),

            _DatePicker(
              label: 'Vignette',
              icon: Icons.local_offer_outlined,
              value: _vignetteExpiryDate,
              onTap: () => _pickDate(
                _vignetteExpiryDate,
                (d) => setState(() => _vignetteExpiryDate = d),
                label: 'Expiration vignette',
              ),
              onClear: () => setState(() => _vignetteExpiryDate = null),
            ),

            const SizedBox(height: 24),
          ]), // fin Column du Form
        ), // fin Form
      ), // fin SingleChildScrollView
          ), // fin Flexible
          // ── Bouton enregistrer — toujours visible hors du scroll ──
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isEdit ? 'Enregistrer les modifications' : 'Enregistrer',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
