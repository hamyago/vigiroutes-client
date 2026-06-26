import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import '../controllers/auth_controller.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_button.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  final bool isProvider;
  const OtpScreen({
    super.key,
    required this.phone,
    this.isProvider = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _otp = '';
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown == 0) {
        t.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleVerification() async {
    final auth = context.read<AuthController>();
    final ok = await auth.verifyOtp(_otp);
    if (!mounted) return;

    if (!ok) return; // erreur affichée par auth.error

    // Attendre que le rôle soit chargé (max 3 secondes)
    String? role = auth.role;
    if (role == null) {
      for (int i = 0; i < 6; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        role = context.read<AuthController>().role;
        if (role != null) break;
      }
    }

    if (!mounted) return;

    if (role == 'provider') {
      // Prestataire connecté → home prestataire
      context.go('/provider/home');
    } else if (role == 'user') {
      // Utilisateur existant → home client
      context.go('/user/home');
    } else {
      // Nouvel utilisateur → compléter le profil
      // Dans l'app client, c'est toujours un automobiliste
      context.go(
        '/auth/profile-setup',
        extra: {'isProvider': false},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final theme = PinTheme(
      width: 52,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('🔐', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Code de vérification',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  text: 'Code envoyé au ',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                  children: [
                    TextSpan(
                      text: widget.phone,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Pinput(
                length: 6,
                defaultPinTheme: theme,
                focusedPinTheme: theme.copyWith(
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (v) => setState(() => _otp = v),
                onCompleted: (v) {
                  setState(() => _otp = v);
                  // Auto-submit quand le code est complet
                  _handleVerification();
                },
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: _countdown > 0
                    ? Text(
                        'Renvoyer dans $_countdown s',
                        style: const TextStyle(color: AppColors.textMuted),
                      )
                    : TextButton(
                        onPressed: () async {
                          await auth.resendOtp(widget.phone);
                          _startCountdown();
                        },
                        child: const Text('Renvoyer le code'),
                      ),
              ),
              const Spacer(),
              AppButton(
                label: 'Confirmer',
                isLoading: auth.isLoading,
                enabled: _otp.length == 6,
                onPressed: _handleVerification,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
