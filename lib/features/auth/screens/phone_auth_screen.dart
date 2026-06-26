import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';

class PhoneAuthScreen extends StatefulWidget {
  final bool isProvider;
  const PhoneAuthScreen({super.key, this.isProvider = false});
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _ctrl = TextEditingController();
  String _phone = '';
  bool _valid = false;
  bool _waiting = false;

  String _e164(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('225')) return '+$d';
    return '+225$d';
  }

  bool _isValid(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    return d.length == 9 || d.length == 10;
  }

  Future<void> _send(AuthController auth) async {
    if (_waiting) return;
    setState(() => _waiting = true);

    void listener() {
      if (!mounted) return;
      if (auth.otpSent && auth.error == null) {
        auth.removeListener(listener);
        setState(() => _waiting = false);
        context.go('/auth/otp', extra: {'phone': _phone, 'isProvider': widget.isProvider});
      } else if (auth.error != null && !auth.isLoading) {
        auth.removeListener(listener);
        setState(() => _waiting = false);
      }
    }

    auth.addListener(listener);
    await auth.sendOtp(_phone);

    if (mounted && !auth.isLoading && !auth.otpSent && auth.error == null) {
      auth.removeListener(listener);
      setState(() => _waiting = false);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final loading = auth.isLoading || _waiting;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/onboarding'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.phone_android, size: 28, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Votre numéro',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Entrez votre numéro de téléphone ivoirien.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(
                    color: _valid ? AppColors.primary : Colors.grey,
                    width: _valid ? 2 : 1,
                  )),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: const Row(children: [
                      Text('🇨🇮', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text('+225', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '07 00 00 00 00',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      style: const TextStyle(fontSize: 18, letterSpacing: 1),
                      onChanged: (v) => setState(() {
                        _valid = _isValid(v);
                        _phone = _e164(v);
                      }),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Text(
                _valid ? 'Numéro : $_phone' : '10 chiffres requis',
                style: TextStyle(
                  fontSize: 12,
                  color: _valid ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(auth.error!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13))),
                  ]),
                ),
              ],
              const Spacer(),
              AppButton(
                label: loading ? 'Envoi en cours...' : 'Recevoir le code',
                isLoading: loading,
                enabled: _valid && !loading,
                onPressed: () => _send(auth),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('Un code à 6 chiffres sera envoyé par SMS.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
