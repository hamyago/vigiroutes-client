import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../auth/controllers/auth_controller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey     = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _whatsappCtrl;
  bool _loading      = false;
  bool _photoLoading = false;

  @override
  void initState() {
    super.initState();
    final user    = context.read<AuthController>().user;
    _nameCtrl     = TextEditingController(text: user?.name ?? '');
    _whatsappCtrl = TextEditingController(text: user?.whatsapp ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _whatsappCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.instance.updateUser({
        'name':     _nameCtrl.text.trim(),
        'whatsapp': _whatsappCtrl.text.trim(),
      });
      if (mounted) await context.read<AuthController>().refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour ✅'),
              backgroundColor: AppColors.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (kIsWeb) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Prendre une photo'),
            onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choisir dans la galerie'),
            onTap: () => Navigator.pop(context, ImageSource.gallery)),
      ])),
    );
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final file   = await picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null) return;
    setState(() => _photoLoading = true);
    try {
      await ApiService.instance.updateUser({'photo_base64': await file.readAsBytes()});
      if (mounted) await context.read<AuthController>().refreshUser();
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Photo mise à jour ✅')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur photo : $e')));
    } finally {
      if (mounted) setState(() => _photoLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthController>();
    final user   = auth.user;
    final letter = (user?.name ?? '?').isNotEmpty ? user!.name[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le profil'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('Enregistrer',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                  child: user?.photoUrl == null
                      ? Text(letter, style: const TextStyle(fontSize: 32, color: AppColors.primary))
                      : null,
                ),
                if (_photoLoading)
                  const Positioned.fill(child: CircleAvatar(
                    radius: 48, backgroundColor: Colors.black38,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                else
                  Positioned(bottom: 0, right: 0,
                    child: Container(
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16))),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nom complet', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _whatsappCtrl,
            decoration: const InputDecoration(labelText: 'WhatsApp (optionnel)', prefixIcon: Icon(Icons.phone)),
            keyboardType: TextInputType.phone,
          ),
        ]),
      ),
    );
  }
}