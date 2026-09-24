// screens/ct/vehicle_add_screen.dart
// Écran ajout / édition de véhicule — Module CT VigiRoutes Client
//
// Dossier : lib/features/ct/screens/vehicle_add_screen.dart
//   (ou lib/screens/ct/vehicle_add_screen.dart selon votre arborescence)
//
// Champs du formulaire :
//   Immatriculation · Numéro carte grise · Marque · Type/Modèle · Catégorie
//   Puissance (CV) · Couleur · Énergie · Places assises · Usage · Date CT

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/models/vehicle_model.dart';
import '../../core/services/ct_service.dart';

class VehicleAddScreen extends StatefulWidget {
  /// Passer un véhicule existant pour passer en mode édition.
  final VehicleModel? vehicle;

  const VehicleAddScreen({super.key, this.vehicle});

  @override
  State<VehicleAddScreen> createState() => _VehicleAddScreenState();
}

class _VehicleAddScreenState extends State<VehicleAddScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMessage;

  // ── Contrôleurs texte ─────────────────────────────────────────────────────
  late final TextEditingController _immatCtrl;
  late final TextEditingController _carteGriseCtrl;
  late final TextEditingController _marqueCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _puissanceCtrl;
  late final TextEditingController _couleurCtrl;
  late final TextEditingController _placesCtrl;

  // ── Dropdowns ─────────────────────────────────────────────────────────────
  String  _categorie = 'VP';
  String? _energie;
  String? _usage;

  // ── Date contrôle technique ────────────────────────────────────────────────
  DateTime? _dateCT;
  final _dateCTCtrl = TextEditingController();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _immatCtrl     = TextEditingController(text: v?.registrationNumber ?? '');
    _carteGriseCtrl = TextEditingController(text: v?.carteGriseNumber ?? '');
    _marqueCtrl    = TextEditingController(text: v?.brand ?? '');
    _typeCtrl      = TextEditingController(text: v?.model ?? '');
    _puissanceCtrl = TextEditingController(
        text: v?.puissanceCv != null ? v!.puissanceCv.toString() : '');
    _couleurCtrl   = TextEditingController(text: v?.color ?? '');
    _placesCtrl    = TextEditingController(
        text: v?.placesAssises != null ? v!.placesAssises.toString() : '');

    _categorie = v?.category ?? 'VP';
    _energie   = v?.energy;
    _usage     = v?.usage;

    if (v?.technicalVisitExpiresAt != null) {
      _dateCT = v!.technicalVisitExpiresAt;
      _dateCTCtrl.text = _dateFmt.format(_dateCT!);
    }
  }

  @override
  void dispose() {
    _immatCtrl.dispose();
    _carteGriseCtrl.dispose();
    _marqueCtrl.dispose();
    _typeCtrl.dispose();
    _puissanceCtrl.dispose();
    _couleurCtrl.dispose();
    _placesCtrl.dispose();
    _dateCTCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDateCT() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateCT ?? now,
      firstDate: DateTime(now.year - 1),   // permet de saisir une date déjà passée
      lastDate: DateTime(now.year + 5),
      helpText: 'Date d\'expiration du contrôle technique',
      confirmText: 'VALIDER',
      cancelText: 'ANNULER',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2196F3),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _dateCT = picked;
        _dateCTCtrl.text = _dateFmt.format(picked);
      });
    }
  }

  // ── Sauvegarde ─────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _errorMessage = null; });

    final data = <String, dynamic>{
      'registration_number':         _immatCtrl.text.trim().toUpperCase(),
      'carte_grise_number':          _carteGriseCtrl.text.trim(),
      'brand':                       _marqueCtrl.text.trim(),
      'model':                       _typeCtrl.text.trim(),
      'category':                    _categorie,
      'energy':                      _energie,
      'color':  _couleurCtrl.text.trim().isEmpty ? null : _couleurCtrl.text.trim(),
      'usage':                       _usage,
      'technical_visit_expires_at':  _dateCT != null
          ? DateFormat('yyyy-MM-dd').format(_dateCT!)
          : null,
      if (_puissanceCtrl.text.trim().isNotEmpty)
        'puissance_cv':   int.tryParse(_puissanceCtrl.text.trim()),
      if (_placesCtrl.text.trim().isNotEmpty)
        'places_assises': int.tryParse(_placesCtrl.text.trim()),
    };

    try {
      if (_isEditing) {
        await CtService.instance.updateVehicle(widget.vehicle!.id, data);
      } else {
        await CtService.instance.createVehicle(data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ── Couleur badge alerte CT ────────────────────────────────────────────────
  Widget? _ctAlertBadge() {
    if (_dateCT == null) return null;
    final days = _dateCT!.difference(DateTime.now()).inDays;
    Color color;
    String label;
    if (days < 0) {
      color = Colors.red;
      label = 'Expiré depuis ${-days} j';
    } else if (days <= 3) {
      color = Colors.red;
      label = 'Expire dans $days j ⚠️';
    } else if (days <= 7) {
      color = Colors.orange;
      label = 'Expire dans $days j';
    } else if (days <= 30) {
      color = Colors.amber.shade700;
      label = 'Expire dans $days j';
    } else {
      return null; // OK, pas besoin de badge
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_active_outlined, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A2E),
        title: Text(
          _isEditing ? 'Modifier le véhicule' : 'Ajouter un véhicule',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 24),
            children: [

              // ─ Identification ──────────────────────────────────────────────
              _SectionTitle('Identification'),
              const SizedBox(height: 8),

              _buildField(
                controller: _immatCtrl,
                label: 'Immatriculation *',
                hint: 'Ex : CI-123-AB',
                icon: Icons.confirmation_number_outlined,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                  LengthLimitingTextInputFormatter(20),
                ],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
                enabled: !_isEditing,
              ),
              const SizedBox(height: 12),

              _buildField(
                controller: _carteGriseCtrl,
                label: 'Numéro carte grise *',
                hint: 'Ex : 0123456789',
                icon: Icons.badge_outlined,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 12),

              _buildField(
                controller: _marqueCtrl,
                label: 'Marque *',
                hint: 'Ex : Toyota, Renault…',
                icon: Icons.directions_car_outlined,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 12),

              _buildField(
                controller: _typeCtrl,
                label: 'Type / Modèle *',
                hint: 'Ex : Corolla, Clio…',
                icon: Icons.drive_file_rename_outline,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 24),

              // ─ Catégorie ───────────────────────────────────────────────────
              _SectionTitle('Catégorie'),
              const SizedBox(height: 8),

              _buildDropdown<String>(
                value: _categorie,
                label: 'Catégorie *',
                icon: Icons.category_outlined,
                items: const ['VP', 'VU', 'Moto', 'Camion'],
                labels: const {
                  'VP':     'VP – Véhicule particulier',
                  'VU':     'VU – Véhicule utilitaire',
                  'Moto':   'Moto',
                  'Camion': 'Camion',
                },
                onChanged: (v) => setState(() => _categorie = v!),
                validator: (v) => v == null ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 24),

              // ─ Caractéristiques ────────────────────────────────────────────
              _SectionTitle('Caractéristiques'),
              const SizedBox(height: 8),

              _buildField(
                controller: _puissanceCtrl,
                label: 'Puissance (CV)',
                hint: 'Ex : 5',
                icon: Icons.speed_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Valeur invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              _buildField(
                controller: _couleurCtrl,
                label: 'Couleur',
                hint: 'Ex : Blanc, Gris…',
                icon: Icons.palette_outlined,
              ),
              const SizedBox(height: 12),

              _buildDropdown<String?>(
                value: _energie,
                label: 'Énergie',
                icon: Icons.local_gas_station_outlined,
                items: const [null, 'gasoil', 'essence', 'hybride', 'electrique'],
                labels: const {
                  null:          '— Sélectionner —',
                  'gasoil':      'Gasoil',
                  'essence':     'Essence',
                  'hybride':     'Hybride',
                  'electrique':  'Électrique',
                },
                onChanged: (v) => setState(() => _energie = v),
              ),
              const SizedBox(height: 12),

              _buildField(
                controller: _placesCtrl,
                label: 'Places assises',
                hint: 'Ex : 5',
                icon: Icons.people_outline,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Valeur invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              _buildDropdown<String?>(
                value: _usage,
                label: 'Usage',
                icon: Icons.assignment_outlined,
                items: const [null, 'public', 'privée'],
                labels: const {
                  null:     '— Sélectionner —',
                  'public': 'Usage public',
                  'privée': 'Usage privé',
                },
                onChanged: (v) => setState(() => _usage = v),
              ),
              const SizedBox(height: 24),

              // ─ Contrôle technique ──────────────────────────────────────────
              _SectionTitle('Contrôle technique'),
              const SizedBox(height: 8),

              // Date picker en lecture seule
              TextFormField(
                controller: _dateCTCtrl,
                readOnly: true,
                onTap: _pickDateCT,
                decoration: InputDecoration(
                  labelText: 'Date d\'expiration du CT',
                  hintText: 'Appuyez pour choisir',
                  prefixIcon: const Icon(Icons.event_outlined, size: 20),
                  suffixIcon: _dateCT != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() {
                            _dateCT = null;
                            _dateCTCtrl.clear();
                          }),
                        )
                      : const Icon(Icons.chevron_right, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF2196F3), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
              ),

              // Badge alerte si date proche
              if (_ctAlertBadge() != null) ...[
                const SizedBox(height: 6),
                _ctAlertBadge()!,
              ],

              const SizedBox(height: 8),

              // Info notifications
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 16, color: Color(0xFF2196F3)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vous recevrez des rappels automatiques 7 jours, 3 jours et la veille de l\'expiration.',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF1976D2)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ─ Erreur serveur ─────────────────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ─ Bouton sauvegarder ─────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _isEditing
                              ? 'Mettre à jour'
                              : 'Ajouter le véhicule',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers widgets ────────────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF2196F3), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String label,
    IconData? icon,
    required List<T> items,
    required Map<T, String> labels,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF2196F3), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      items: items
          .map((item) => DropdownMenuItem<T>(
                value: item,
                child: Text(labels[item] ?? item.toString()),
              ))
          .toList(),
    );
  }
}

// ── Section title ──────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2196F3),
            letterSpacing: 1.2,
          ),
        ),
      );
}
