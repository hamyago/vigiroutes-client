import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/emergency_controller.dart';
import '../../../core/models/emergency_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/controllers/auth_controller.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthController>().user;
      if (user != null) {
        context.read<EmergencyController>().setUser(user);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EmergencyController>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (ctrl.isCountingDown) ctrl.cancelCountdown();
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Urgence',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (ctrl.state) {
          EmergencyState.idle        => _IdleView(pulseCtrl: _pulseCtrl),
          EmergencyState.countdown   => _CountdownView(ctrl: ctrl),
          EmergencyState.sending     => const _SendingView(),
          EmergencyState.done        => _DoneView(ctrl: ctrl),
          EmergencyState.webFallback => _WebFallbackView(ctrl: ctrl),
          EmergencyState.error       => _ErrorView(ctrl: ctrl),
        },
      ),
    );
  }
}

// ── Vue principale ─────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final AnimationController pulseCtrl;
  const _IdleView({required this.pulseCtrl});

  static const _types = [
    EmergencyType.accident,
    EmergencyType.fire,
    EmergencyType.medical,
  ];
  static const _colors = [
    Color(0xFFE53E3E),
    Color(0xFFFF6B35),
    Color(0xFF3182CE),
  ];
  static const _descriptions = [
    'Collision, renversement\nou blessés sur la route',
    'Véhicule ou bâtiment\nen feu',
    'Personne inconsciente,\ncrise cardiaque...',
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = context.read<EmergencyController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1 + 0.05 * pulseCtrl.value),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3 + 0.1 * pulseCtrl.value)),
              ),
              child: const Column(
                children: [
                  Text('🚨', style: TextStyle(fontSize: 36)),
                  SizedBox(height: 8),
                  Text(
                    'Service d\'urgence',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Gratuit · Appel immédiat + alerte aux secours',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          ...List.generate(_types.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _EmergencyButton(
              type: _types[i],
              color: _colors[i],
              description: _descriptions[i],
              onTap: () => ctrl.startCountdown(_types[i]),
            ),
          )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Numéros d\'urgence CI',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const SizedBox(height: 10),
                _PhoneRow('🚒 Sapeurs-Pompiers', '180', Colors.red.shade300),
                const SizedBox(height: 6),
                _PhoneRow('🏥 SAMU', '185', Colors.blue.shade300),
                const SizedBox(height: 6),
                _PhoneRow('👮 Police', '110', Colors.orange.shade300),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  final EmergencyType type;
  final Color color;
  final String description;
  final VoidCallback onTap;
  const _EmergencyButton({
    required this.type,
    required this.color,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(type.icon, style: const TextStyle(fontSize: 38)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 17)),
                    const SizedBox(height: 3),
                    Text(description,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Appel ${type.phoneNumber} — ${type.serviceName}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70, size: 28),
            ],
          ),
        ),
      );
}

class _PhoneRow extends StatelessWidget {
  final String label;
  final String number;
  final Color color;
  const _PhoneRow(this.label, this.number, this.color);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(number,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1)),
          ),
        ],
      );
}

// ── Compte à rebours ───────────────────────────────────────────────────────────

class _CountdownView extends StatefulWidget {
  final EmergencyController ctrl;
  const _CountdownView({required this.ctrl});

  @override
  State<_CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends State<_CountdownView> {
  static const _colors = {
    EmergencyType.accident: Color(0xFFE53E3E),
    EmergencyType.fire:     Color(0xFFFF6B35),
    EmergencyType.medical:  Color(0xFF3182CE),
  };

  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl  = widget.ctrl;
    final type  = ctrl.selectedType!;
    final color = _colors[type]!;
    final count = ctrl.countdown;

    return Container(
      key: const ValueKey('countdown'),
      color: color.withValues(alpha: 0.12),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(type.icon, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                'Appel ${type.serviceName}',
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Le ${type.phoneNumber} sera appelé dans',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      value: count / 30,
                      strokeWidth: 8,
                      backgroundColor: color.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Text('$count',
                      style: TextStyle(
                          color: color,
                          fontSize: 48,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 24),
              // AJOUTÉ : détail facultatif — n'empêche jamais l'envoi. Le
              // compte à rebours continue même pendant la saisie ; si rien
              // n'est tapé, l'alerte part quand même normalement.
              TextField(
                controller: _descCtrl,
                onChanged: ctrl.setDescription,
                maxLines: 2,
                minLines: 1,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Un détail à ajouter ? (facultatif)',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: color),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: ctrl.cancelCountdown,
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text('Annuler',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white38, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: ctrl.triggerNow,
                  icon: const Icon(Icons.phone, size: 20),
                  label: const Text('Appeler maintenant',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Envoi ──────────────────────────────────────────────────────────────────────

class _SendingView extends StatelessWidget {
  const _SendingView();

  @override
  Widget build(BuildContext context) => const Center(
        key: ValueKey('sending'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 24),
            Text('Envoi de l\'alerte...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              'Votre position GPS est transmise aux secours.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ── Succès ─────────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  final EmergencyController ctrl;
  const _DoneView({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final type = ctrl.selectedType!;
    return Center(
      key: const ValueKey('done'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(
                  color: AppColors.successLight, shape: BoxShape.circle),
              child: const Center(
                child: Icon(Icons.check_circle,
                    color: AppColors.success, size: 52),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Alerte envoyée !',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              'Les ${type.serviceName} (${type.phoneNumber}) ont été contactés.\n'
              'Votre position GPS a été transmise aux équipes Admin VigiRoutes.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => ctrl.shareLocation(),
                icon: const Icon(Icons.phone),
                label: Text('Rappeler le ${type.phoneNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ctrl.reset();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Retour à l\'accueil',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ── Vue web : appel impossible depuis navigateur desktop ──────────────────────

class _WebFallbackView extends StatelessWidget {
  final EmergencyController ctrl;
  const _WebFallbackView({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final type = ctrl.selectedType!;
    return Center(
      key: const ValueKey('webFallback'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(
                  color: AppColors.successLight, shape: BoxShape.circle),
              child: const Center(
                child: Icon(Icons.check_circle,
                    color: AppColors.success, size: 52),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Alerte enregistrée !',
              style: TextStyle(color: Colors.white, fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            const Text(
              "L'équipe Admin VigiRoutes a été notifiée et surveille "
              "votre situation en temps réel.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Numéro à appeler manuellement (web ne peut pas déclencher l'appel)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE53E3E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFE53E3E).withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    'Appelez maintenant le',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.phoneNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  Text(
                    type.serviceName,
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Sur téléphone mobile, le composeur s'ouvre automatiquement.",
              style: TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ctrl.reset();
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Retour à l'accueil",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Erreur ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final EmergencyController ctrl;
  const _ErrorView({required this.ctrl});

  @override
  Widget build(BuildContext context) => Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              Text(
                ctrl.errorMessage ?? 'Une erreur est survenue.',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: ctrl.reset,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary),
                child: const Text('Réessayer',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
}
