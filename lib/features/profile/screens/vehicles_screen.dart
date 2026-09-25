import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';

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

  // FIX Bug C : dialog de confirmation + message d'erreur lisible
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
    // Capturer le messenger avant tout await pour éviter le "use_build_context_synchronously"
    // et l'appel sur un context démonté. hideCurrentSnackBar() évite aussi d'empiler
    // plusieurs snackbars si l'utilisateur supprime plusieurs véhicules rapidement.
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    try {
      await ApiService.instance.deleteVehicle(id);
      await _load();
      // Vérifier mounted APRÈS les awaits
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        content: Text('Véhicule supprimé'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      // FIX Bug C : message d'erreur lisible au lieu du raw DioException
      final msg = _readableError(e);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  /// FIX Bug C : extrait un message lisible depuis les erreurs Dio/HTTP.
  String _readableError(Object e) {
    final raw = e.toString();
    // DioException contient souvent le message du serveur dans son toString
    if (raw.contains('500') || raw.contains('Internal Server Error')) {
      return 'Impossible de supprimer ce véhicule (erreur serveur).\n'
             'Vérifiez que le véhicule n\'a pas de réservation active.';
    }
    if (raw.contains('404')) {
      return 'Véhicule introuvable. Il a peut-être déjà été supprimé.';
    }
    if (raw.contains('403') || raw.contains('unauthorized')) {
      return 'Vous n\'êtes pas autorisé à supprimer ce véhicule.';
    }
    if (raw.contains('SocketException') || raw.contains('connection')) {
      return 'Pas de connexion internet. Réessayez.';
    }
    return 'Erreur lors de la suppression. Réessayez.';
  }

  Future<void> _showAddVehicle() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddVehicleSheet(),
    );
    if (added == true) await _load();
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
                      final label = '${v.brand} ${v.model} ${v.plate}'.trim();
                      return _VehicleTile(
                        vehicle: v,
                        // FIX Bug C : passer par _confirmDelete
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
  final VoidCallback onDelete;
  const _VehicleTile({required this.vehicle, required this.onDelete});

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
                    Text(vehicle.plate,
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
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: onDelete),
            ]),
            const SizedBox(height: 10),
            // Badges CT / Assurance / Vignette
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ExpiryBadge(
                  icon: Icons.verified_outlined,
                  label: 'CT',
                  date: vehicle.ctExpiryDate,
                ),
                _ExpiryBadge(
                  icon: Icons.shield_outlined,
                  label: 'Assurance',
                  date: vehicle.insuranceExpiryDate,
                ),
                _ExpiryBadge(
                  icon: Icons.local_offer_outlined,
                  label: 'Vignette',
                  date: vehicle.vignetteExpiryDate,
                ),
              ],
            ),
          ],
        ),
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

// ─── Formulaire d'ajout ───────────────────────────────────────────────────────

class _AddVehicleSheet extends StatefulWidget {
  const _AddVehicleSheet();
  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _formKey        = GlobalKey<FormState>();
  final _brandCtrl      = TextEditingController();
  final _modelCtrl      = TextEditingController();
  final _plateCtrl      = TextEditingController();
  final _colorCtrl      = TextEditingController();
  final _yearCtrl       = TextEditingController();
  final _carteGriseCtrl = TextEditingController();
  DateTime? _ctExpiryDate;
  DateTime? _insuranceExpiryDate;
  DateTime? _vignetteExpiryDate;
  bool _loading = false;

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    _carteGriseCtrl.dispose();
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      await ApiService.instance.addVehicle({
        'brand': _brandCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'registration_number': _plateCtrl.text.trim().toUpperCase(),
        if (_colorCtrl.text.trim().isNotEmpty) 'color': _colorCtrl.text.trim(),
        if (_yearCtrl.text.trim().isNotEmpty)
          'year': int.tryParse(_yearCtrl.text.trim()),
        if (_carteGriseCtrl.text.trim().isNotEmpty)
          'carte_grise_number': _carteGriseCtrl.text.trim(),
        if (_ctExpiryDate != null)
          'technical_visit_expires_at':
              DateFormat('yyyy-MM-dd').format(_ctExpiryDate!),
        if (_insuranceExpiryDate != null)
          'insurance_expires_at':
              DateFormat('yyyy-MM-dd').format(_insuranceExpiryDate!),
        if (_vignetteExpiryDate != null)
          'vignette_expires_at':
              DateFormat('yyyy-MM-dd').format(_vignetteExpiryDate!),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Véhicule ajouté'),
            backgroundColor: AppColors.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: SingleChildScrollView(
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
            const Text('Ajouter un véhicule',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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

            // ── Couleur & Année sur la même ligne ──
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _colorCtrl,
                  decoration: _dec('Couleur', hint: 'Blanc'),
                ),
              ),
              const SizedBox(width: 10),
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
            ]),
            const SizedBox(height: 12),

            // ── N° Carte grise ──
            TextFormField(
              controller: _carteGriseCtrl,
              decoration: _dec('N° Carte grise', hint: 'CI-123456-A',
                  icon: Icons.article_outlined),
              textCapitalization: TextCapitalization.characters,
            ),
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

            // ── Bouton enregistrer ──
            SizedBox(
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
                    : const Text('Enregistrer',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
