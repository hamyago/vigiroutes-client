import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/service_type_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/service_type_service.dart';
import '../../../shared/widgets/custom_button.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isProvider;
  const ProfileSetupScreen({super.key, this.isProvider = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  final _locationService = LocationService();

  final List<String> _selectedServices = [];
  bool   _loadingLocation = false;
  bool   _loadingServices = false;
  double? _lat, _lng;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    if (ServiceTypeService.instance.isLoaded) return;
    setState(() => _loadingServices = true);
    await ServiceTypeService.instance.load();
    if (mounted) setState(() => _loadingServices = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _loadingLocation = true);
    final pos = await _locationService.getCurrentPosition();
    setState(() {
      _lat = pos?.latitude;
      _lng = pos?.longitude;
      _loadingLocation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthController>();
    final services = ServiceTypeService.instance.serviceTypes;

    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon profil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('👤', style: TextStyle(fontSize: 40)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Champ requis' : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Numéro WhatsApp (optionnel)',
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                    hintText: '+225...',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                if (widget.isProvider) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Types de services proposés',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  if (_loadingServices)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: services
                          .map((s) => _ServiceChip(
                                service:  s,
                                selected: _selectedServices.contains(s.id),
                                onTap: () {
                                  setState(() {
                                    if (_selectedServices.contains(s.id)) {
                                      _selectedServices.remove(s.id);
                                    } else {
                                      _selectedServices.add(s.id);
                                    }
                                  });
                                },
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Votre localisation',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _getLocation,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _lat != null
                            ? AppColors.successLight
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _lat != null
                              ? AppColors.success : AppColors.border,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          _lat != null
                              ? Icons.check_circle
                              : Icons.location_on_outlined,
                          color: _lat != null
                              ? AppColors.success : AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _loadingLocation
                              ? 'Localisation en cours...'
                              : _lat != null
                                  ? 'Position enregistrée ✓'
                                  : 'Appuyez pour détecter ma position',
                          style: TextStyle(
                            color: _lat != null
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (_loadingLocation) ...[
                          const Spacer(),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                AppButton(
                  label: 'Créer mon compte',
                  isLoading: auth.isLoading,
                  enabled: true,
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    if (widget.isProvider) {
                      if (_selectedServices.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text(
                              'Sélectionnez au moins un type de service.')),
                        );
                        return;
                      }
                      if (_lat == null) {
                        await _getLocation();
                        if (_lat == null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text(
                                'La localisation est requise.')),
                          );
                          return;
                        }
                      }
                      await auth.completeProviderProfile(
                        name:         _nameCtrl.text.trim(),
                        phone:        _phoneCtrl.text.trim(),
                        serviceTypes: _selectedServices,
                        latitude:     _lat!,
                        longitude:    _lng!,
                      );
                      if (mounted) context.go('/provider/home');
                    } else {
                      await auth.completeUserProfile(
                        name:  _nameCtrl.text.trim(),
                        phone: _phoneCtrl.text.trim(),
                      );
                      if (mounted) context.go('/user/home');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final ServiceTypeModel service;
  final bool selected;
  final VoidCallback onTap;
  const _ServiceChip({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(service.emoji),
              const SizedBox(width: 6),
              Text(
                service.name,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
}
