import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Écran de choix affiché quand l'utilisateur appuie sur le bouton central.
/// Il oriente soit vers une demande de dépannage, soit vers l'alerte urgences.
class ActionChoiceScreen extends StatelessWidget {
  const ActionChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('De quoi avez-vous besoin ?'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChoiceCard(
                color: const Color(0xFFFF6B35),
                icon: Icons.bolt,
                title: 'Me faire dépanner',
                subtitle: 'On vous envoie automatiquement le prestataire\nle mieux noté et le plus proche',
                onTap: () =>
                    context.pushReplacement('/user/request?mode=auto'),
              ),
              const SizedBox(height: 16),
              _ChoiceCard(
                color: const Color(0xFF4299E1),
                icon: Icons.storefront,
                title: 'Choisir mon garage',
                subtitle: 'Sélectionner vous-même un prestataire\nparmi ceux à proximité',
                onTap: () =>
                    context.pushReplacement('/user/request?mode=manual'),
              ),
              const SizedBox(height: 16),
              _ChoiceCard(
                color: const Color(0xFFE53E3E),
                icon: Icons.emergency,
                title: 'Alerter les urgences',
                subtitle: 'Pompiers · SAMU · secours',
                onTap: () => context.pushReplacement('/user/emergency'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.92),
                            fontSize: 13,
                            height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
