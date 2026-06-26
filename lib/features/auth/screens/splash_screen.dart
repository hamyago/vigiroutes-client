import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../../../core/constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _roadCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset>  _textSlide;
  late Animation<double> _pulse;

  final _taglines = ['Dépannage rapide', 'Partout en CI', 'En 3 clics'];
  int    _tagIndex    = 0;
  String _displayedTag = '';

  @override
  void initState() {
    super.initState();

    _roadCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..repeat();

    _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400),
    );
    _logoScale = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
    );
    _logoFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _textFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4), end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
    ));

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _entryCtrl.forward().then((_) => _startTyping());
    _navigate();
  }

  Future<void> _startTyping() async {
    while (mounted) {
      final tag = _taglines[_tagIndex % _taglines.length];
      for (int i = 0; i <= tag.length; i++) {
        if (!mounted) return;
        setState(() => _displayedTag = tag.substring(0, i));
        await Future.delayed(const Duration(milliseconds: 65));
      }
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() { _tagIndex++; _displayedTag = ''; });
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  // ── Navigation corrigée ────────────────────────────────────────────────────
  Future<void> _navigate() async {
    // Attendre minimum 3s pour l'animation
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final auth = context.read<AuthController>();

    // Attendre que Firebase Auth se résolve (max 10s)
    int waitAuth = 0;
    while (auth.state == AuthState.unknown && waitAuth < 10000) {
      await Future.delayed(const Duration(milliseconds: 200));
      waitAuth += 200;
    }
    if (!mounted) return;

    if (auth.state != AuthState.authenticated) {
      // Non connecté → onboarding
      context.go('/onboarding');
      return;
    }

    // Connecté — attendre que le profil soit chargé depuis l'API (max 8s)
    int waitProfile = 0;
    while (waitProfile < 8000) {
      await Future.delayed(const Duration(milliseconds: 300));
      waitProfile += 300;
      if (!mounted) return;

      final a = context.read<AuthController>();
      if (a.isUser) {
        context.go('/user/home');
        return;
      }
      if (a.isProvider) {
        context.go('/provider/home');
        return;
      }
    }

    // Après 8s, si toujours pas de rôle → l'utilisateur est nouveau
    // ou le backend est inaccessible → profile-setup
    if (!mounted) return;
    context.go('/auth/profile-setup', extra: {'isProvider': false});
  }

  @override
  void dispose() {
    _roadCtrl.dispose();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  int get _dotIndex => _tagIndex % 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF9),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.40,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _roadCtrl,
              builder: (_, __) => CustomPaint(
                painter: _RoadPainter(_roadCtrl.value),
              ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: ScaleTransition(
                      scale: _pulse,
                      child: Image.asset(
                        'assets/icons/vigiroutes_logo.png',
                        width: 90, height: 90,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'Poppins', fontSize: 32,
                          fontWeight: FontWeight.w700, letterSpacing: -0.5,
                          color: Color(0xFF1A1A1A),
                        ),
                        children: [
                          TextSpan(text: 'Vigi'),
                          TextSpan(text: 'Routes',
                              style: TextStyle(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _textFade,
                  child: SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _displayedTag.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 12,
                            letterSpacing: 2.5, color: Color(0xFF999999),
                          ),
                        ),
                        _BlinkingCursor(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _textFade,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _dotIndex ? 18 : 6, height: 6,
                      decoration: BoxDecoration(
                        color: i == _dotIndex
                            ? AppColors.primary : const Color(0xFFEADDD0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
                  ),
                ),
              ],
            ),
          ),
          FadeTransition(
            opacity: _textFade,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Text('OYOP MT',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 10,
                  letterSpacing: 3, color: Color(0xFFCCCCCC),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}
class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _ctrl,
    child: Container(
      width: 2, height: 14,
      margin: const EdgeInsets.only(left: 2),
      color: AppColors.primary,
    ),
  );
}

class _RoadPainter extends CustomPainter {
  final double progress;
  _RoadPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width; final H = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H * 0.58),
        Paint()..color = const Color(0xFFF0EBE3));
    canvas.drawCircle(Offset(W * 0.84, H * 0.18), 22,
        Paint()..color = const Color(0xFFFAEEDA));
    canvas.drawCircle(Offset(W * 0.84, H * 0.18), 14,
        Paint()..color = const Color(0xFFEF9F27));
    final hillPath = Path()
      ..moveTo(0, H * 0.55)
      ..cubicTo(W * 0.25, H * 0.30, W * 0.5, H * 0.48, W * 0.7, H * 0.34)
      ..cubicTo(W * 0.85, H * 0.25, W * 0.95, H * 0.44, W, H * 0.55)
      ..lineTo(W, H * 0.60)..lineTo(0, H * 0.60)..close();
    canvas.drawPath(hillPath, Paint()..color = const Color(0xFFE8E0D5));
    canvas.drawRect(Rect.fromLTWH(0, H * 0.58, W, H * 0.42),
        Paint()..color = const Color(0xFFD3CFC8));
    final dashPaint = Paint()
      ..color = const Color(0xFFFFFDF9)..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const dashLen = 28.0; const gapLen = 20.0;
    final total = dashLen + gapLen;
    final offset = progress * total; final y = H * 0.75;
    double x = -total + offset;
    while (x < W + total) {
      canvas.drawLine(Offset(x, y), Offset(x + dashLen, y), dashPaint);
      x += total;
    }
    final stripePaint = Paint()..color = const Color(0xFFFF6B35)..strokeWidth = 2;
    canvas.drawLine(Offset(0, H * 0.59), Offset(W, H * 0.59), stripePaint);
    canvas.drawLine(Offset(0, H * 0.995), Offset(W, H * 0.995), stripePaint);
    for (int i = 0; i < 5; i++) {
      final tx = ((i * 64.0 - progress * total * 3) % (W + 40)) - 20;
      _drawTree(canvas, Offset(tx, H * 0.54), H * 0.07);
    }
    final carX = ((W * 0.55 + progress * total * 5) % (W + 60)) - 30;
    _drawCar(canvas, Offset(carX, H * 0.67), 0.7);
  }

  void _drawTree(Canvas canvas, Offset pos, double size) {
    canvas.drawRect(Rect.fromLTWH(pos.dx - size * 0.2, pos.dy, size * 0.4, size * 1.2),
        Paint()..color = const Color(0xFFB4B2A9));
    canvas.drawCircle(pos.translate(0, -size * 0.4), size * 0.9,
        Paint()..color = const Color(0xFF888780));
    canvas.drawCircle(pos.translate(0, -size * 0.9), size * 0.65,
        Paint()..color = const Color(0xFF5F5E5A));
  }

  void _drawCar(Canvas canvas, Offset pos, double scale) {
    final s = scale; canvas.save(); canvas.translate(pos.dx, pos.dy);
    canvas.drawOval(Rect.fromCenter(center: Offset(22 * s, 13 * s),
        width: 44 * s, height: 8),
        Paint()..color = const Color(0x14000000));
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, -2 * s, 44 * s, 14 * s), Radius.circular(4 * s)),
        Paint()..color = const Color(0xFFFF6B35));
    canvas.drawRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(8 * s, -12 * s, 26 * s, 12 * s),
        topLeft: Radius.circular(5 * s), topRight: Radius.circular(5 * s)),
        Paint()..color = const Color(0xFFFF8C5A));
    final winPaint = Paint()..color = const Color(0xB2FFFDF9);
    canvas.drawRect(Rect.fromLTWH(10 * s, -10 * s, 10 * s, 8 * s), winPaint);
    canvas.drawRect(Rect.fromLTWH(22 * s, -10 * s, 10 * s, 8 * s), winPaint);
    final wheelPaint = Paint()..color = const Color(0xFF2C2C2A);
    canvas.drawCircle(Offset(10 * s, 12 * s), 6 * s, wheelPaint);
    canvas.drawCircle(Offset(34 * s, 12 * s), 6 * s, wheelPaint);
    final hubPaint = Paint()..color = const Color(0xFFD3D1C7);
    canvas.drawCircle(Offset(10 * s, 12 * s), 3 * s, hubPaint);
    canvas.drawCircle(Offset(34 * s, 12 * s), 3 * s, hubPaint);
    canvas.drawRect(Rect.fromLTWH(40 * s, 2 * s, 4 * s, 4 * s),
        Paint()..color = const Color(0xFFFAEEDA));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.progress != progress;
}
