import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';

/// Foire aux questions — écran interne accessible depuis le profil (/user/faq).
/// Questions/réponses regroupées par thème, présentées en accordéon.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Foire aux questions'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text(
            'Vous trouverez ci-dessous les réponses aux questions les plus '
            'fréquentes sur l\'utilisation de VigiRoutes.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          for (final section in _faq) _FaqSection(section: section),
          const SizedBox(height: 24),
          _ContactCard(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _FaqSection extends StatelessWidget {
  final _Section section;
  const _FaqSection({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4),
          child: Row(
            children: [
              Icon(section.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < section.items.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.divider),
                _FaqTile(item: section.items[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FaqTile extends StatelessWidget {
  final _Qa item;
  const _FaqTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textMuted,
        title: Text(
          item.q,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Text(
            item.a,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  Future<void> _mail() async {
    final uri = Uri.parse('mailto:support@vigiroutes.com');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vous ne trouvez pas votre réponse ?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Notre équipe support est à votre disposition.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _mail,
            icon: const Icon(Icons.mail_outline, size: 18),
            label: const Text('Contacter le support'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contenu
// ---------------------------------------------------------------------------

class _Section {
  final String title;
  final IconData icon;
  final List<_Qa> items;
  const _Section(this.title, this.icon, this.items);
}

class _Qa {
  final String q;
  final String a;
  const _Qa(this.q, this.a);
}

const List<_Section> _faq = [
  _Section('Général', Icons.info_outline, [
    _Qa(
      'Qu\'est-ce que VigiRoutes ?',
      'VigiRoutes est une plateforme d\'assistance routière et de sécurité. '
          'Elle vous met en relation avec des dépanneurs et remorqueurs agréés '
          'ainsi qu\'avec les services de secours (SAMU, pompiers), grâce à la '
          'géolocalisation en temps réel, pour accélérer votre prise en charge.',
    ),
    _Qa(
      'L\'application est-elle payante ?',
      'Non. L\'application est entièrement gratuite pour les particuliers. '
          'Vous ne réglez, le cas échéant, que la prestation de dépannage '
          'convenue directement avec le prestataire.',
    ),
    _Qa(
      'Comment créer un compte ?',
      'Il vous suffit de votre numéro de téléphone. Un code de vérification '
          '(OTP) vous est envoyé par SMS pour confirmer votre inscription.',
    ),
  ]),
  _Section('Dépannage & remorquage', Icons.car_repair, [
    _Qa(
      'Comment demander un dépannage ?',
      'Depuis l\'accueil, appuyez sur le bouton d\'action puis choisissez '
          '« Me faire dépanner ». Indiquez la nature de la panne (pneu, '
          'batterie, remorquage…) et confirmez votre position.',
    ),
    _Qa(
      'Comment le prestataire est-il choisi ?',
      'Les prestataires agréés les plus proches de votre position sont '
          'sollicités. Vous suivez ensuite celui qui accepte de prendre en '
          'charge votre demande.',
    ),
    _Qa(
      'Puis-je annuler une demande ?',
      'Oui, tant que votre demande n\'a pas encore été prise en charge par un '
          'prestataire, ou selon les conditions affichées lors de la demande.',
    ),
  ]),
  _Section('Urgences', Icons.emergency_outlined, [
    _Qa(
      'Comment alerter les secours ?',
      'Depuis le bouton d\'action, choisissez « Alerter les urgences » '
          '(Pompiers · SAMU · secours). Votre position est transmise afin de '
          'faciliter et d\'accélérer l\'intervention.',
    ),
    _Qa(
      'VigiRoutes remplace-t-il les numéros d\'urgence officiels ?',
      'Non. VigiRoutes est un outil complémentaire aux dispositifs publics de '
          'gestion des urgences et ne s\'y substitue pas.',
    ),
  ]),
  _Section('Suivi de l\'intervention', Icons.my_location, [
    _Qa(
      'Comment suivre mon intervention ?',
      'Une fois votre demande prise en charge, un écran de suivi affiche en '
          'temps réel la position du prestataire et l\'état d\'avancement de '
          'l\'intervention.',
    ),
    _Qa(
      'Pourquoi l\'application demande-t-elle ma position ?',
      'Votre position permet de transmettre votre demande, d\'identifier le '
          'prestataire le plus proche et de coordonner l\'intervention. La '
          'géolocalisation n\'est activée que lorsque cela est nécessaire au '
          'service.',
    ),
  ]),
  _Section('Pièces détachées auto', Icons.build_circle_outlined, [
    _Qa(
      'Comment acheter des pièces détachées ?',
      'Rendez-vous dans la rubrique « Pièces détachées auto ». Parcourez les '
          'boutiques agréées, consultez leurs produits et passez commande '
          'directement depuis l\'application.',
    ),
    _Qa(
      'Où retrouver mes commandes ?',
      'Vos commandes de pièces sont accessibles dans la section dédiée de la '
          'rubrique « Pièces détachées auto ».',
    ),
  ]),
  _Section('Avis', Icons.star_outline, [
    _Qa(
      'Comment noter un prestataire ?',
      'À la fin d\'une intervention, vous pouvez attribuer une note et laisser '
          'un commentaire depuis l\'écran d\'avis ou depuis votre historique '
          'd\'interventions.',
    ),
  ]),
  _Section('Compte & confidentialité', Icons.lock_outline, [
    _Qa(
      'Comment modifier mes informations ?',
      'Rendez-vous dans Profil → Modifier le profil pour mettre à jour vos '
          'informations personnelles et votre photo.',
    ),
    _Qa(
      'Mes données sont-elles protégées ?',
      'Oui. Vos données sont traitées conformément à la législation '
          'ivoirienne applicable. Pour en savoir plus, consultez Profil → '
          'Politique de confidentialité.',
    ),
    _Qa(
      'Comment supprimer mon compte ?',
      'Vous disposez d\'un droit de suppression de votre compte et de vos '
          'données. Vous pouvez en faire la demande à l\'adresse '
          'privacy@vigiroutes.com. Voir la Politique de confidentialité pour '
          'le détail de vos droits.',
    ),
  ]),
];
