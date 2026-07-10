import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/cgu_checkbox.dart';

class PhoneAuthScreen extends StatefulWidget {
  final bool isProvider;
  const PhoneAuthScreen({super.key, this.isProvider = false});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _controller = TextEditingController();
  String _phoneNumber = '';
  bool   _valid       = false;
  bool   _waitingForOtp = false; // ← nouveau flag
  bool   _cguAccepted   = false; // case CGU obligatoire

  /// Format E.164 pour Firebase
  /// Numéros CI 10 chiffres avec 0 → +225XXXXXXXXXX
  String _buildE164(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 && digits.startsWith('0')) {
      return '+225$digits';
    }
    if (digits.length == 9 && !digits.startsWith('0')) {
      return '+2250$digits';
    }
    return '+225$digits';
  }

  bool _isValid(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    return (digits.length == 10 && digits.startsWith('0')) ||
           (digits.length == 9 && !digits.startsWith('0'));
  }

  // ─── CORRECTION PRINCIPALE ──────────────────────────────────────────────────
  // verifyPhoneNumber() est asynchrone : Firebase appelle codeSent()
  // APRÈS que sendOtp() revient. On utilise un listener pour détecter
  // le changement d'état et naviguer au bon moment.
  Future<void> _handleSendOtp(AuthController auth) async {
    if (_waitingForOtp) return;
    setState(() => _waitingForOtp = true);

    void listener() {
      if (!mounted) return;
      if (auth.otpSent && auth.error == null) {
        auth.removeListener(listener);
        setState(() => _waitingForOtp = false);
        context.go(
          '/auth/otp',
          extra: {
            'phone':      _phoneNumber,
            'isProvider': widget.isProvider,
          },
        );
      } else if (auth.error != null && !auth.isLoading) {
        auth.removeListener(listener);
        setState(() => _waitingForOtp = false);
      }
    }

    auth.addListener(listener);
    await auth.sendOtp(_phoneNumber);

    if (mounted && !auth.isLoading && !auth.otpSent && auth.error == null) {
      auth.removeListener(listener);
      setState(() => _waitingForOtp = false);
    }
  }
  // ────────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isLoading = auth.isLoading || _waitingForOtp;

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
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/icons/vigiroutes_logo.png',
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Votre numéro',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isProvider
                    ? 'Entrez le numéro de votre compte prestataire.'
                    : 'Entrez votre numéro de téléphone pour continuer.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _valid ? AppColors.primary : Colors.grey,
                      width: _valid ? 2 : 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      child: const Row(
                        children: [
                          Text('🇨🇮', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Text(
                            '+225',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0747457878',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                        ),
                        style: const TextStyle(fontSize: 18, letterSpacing: 1),
                        onChanged: (value) {
                          setState(() {
                            _valid = _isValid(value);
                            if (_valid) _phoneNumber = _buildE164(value);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _valid
                    ? 'Numéro Firebase : $_phoneNumber'
                    : 'Saisissez 10 chiffres en commençant par 0',
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
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          auth.error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),
              CguCheckbox(
                value: _cguAccepted,
                onChanged: (v) => setState(() => _cguAccepted = v),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: isLoading ? 'Envoi en cours...' : 'Recevoir le code',
                isLoading: isLoading,
                enabled: _valid && _cguAccepted && !isLoading,
                onPressed: () => _handleSendOtp(auth),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Un code à 6 chiffres sera envoyé par SMS.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
