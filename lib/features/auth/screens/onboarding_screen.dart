import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class _Page {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  const _Page({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _current = 0;

  final _pages = const [
    _Page(
      emoji: '🚗',
      title: 'Panne ? On arrive !',
      subtitle:
          'Trouvez un professionnel de dépannage qualifié en moins de 3 minutes, où que vous soyez en Côte d\'Ivoire.',
      color: AppColors.primary,
    ),
    _Page(
      emoji: '📍',
      title: 'Géolocalisation précise',
      subtitle:
          'Visualisez les prestataires disponibles autour de vous sur la carte et suivez leur arrivée en temps réel.',
      color: AppColors.accent,
    ),
    _Page(
      emoji: '💸',
      title: 'Paiement simplifié',
      subtitle:
          'Payez par Orange Money, Wave ou carte bancaire. Le tarif est affiché avant confirmation — aucune surprise.',
      color: AppColors.success,
    ),
    _Page(
      emoji: '⭐',
      title: 'Prestataires certifiés',
      subtitle:
          'Chaque professionnel est vérifié par Oyop MT. Consultez les avis et notations avant de faire votre choix.',
      color: Color(0xFF9F7AEA),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_current];
    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  page.color,
                  page.color.withValues(alpha: 0.7),
                  AppColors.dark,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Bouton Passer
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: () => context.go('/auth/phone'),
                      child: Text(
                        'Passer',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _PageContent(page: _pages[i]),
                  ),
                ),

                // Dots + boutons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      // Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _current ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _current
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (_current < _pages.length - 1)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: page.color,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Suivant',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      else
                        // ── Dernière page : un seul bouton automobiliste ──
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => context.go('/auth/phone'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.dark,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Commencer',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _Page page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(page.emoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 32),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              page.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.85),
                height: 1.6,
              ),
            ),
          ],
        ),
      );
}
