import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Politique de confidentialité — écran interne (contenu issu des CGU).
/// Accessible depuis le profil et depuis l'écran d'inscription.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Politique de confidentialité'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: _content.length,
        itemBuilder: (context, i) {
          final block = _content[i];
          switch (block.type) {
            case 'h':
              return Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 20, bottom: 8),
                child: Text(
                  block.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              );
            case 'b':
              return Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                    ),
                    Expanded(
                      child: Text(
                        block.text,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],
                ),
              );
            default:
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  block.text,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              );
          }
        },
      ),
    );
  }
}

class _P {
  final String type; // 'h' titre, 'b' puce, 'p' paragraphe
  final String text;
  const _P(this.type, this.text);
}

const List<_P> _content = [
    _P('h', 'PROTECTION DES DONNÉES À CARACTÈRE PERSONNEL'),
    _P('p', 'Dans le cadre de l\'exploitation de la Plateforme, OYOP Multiservices & Transport collecte et traite des données à caractère personnel conformément à la législation ivoirienne en vigueur, notamment la loi relative à la protection des données à caractère personnel ainsi qu\'aux recommandations de l\'autorité nationale compétente.'),
    _P('p', 'Les données ne sont accessibles qu\'aux personnes habilitées et sont conservées pendant la durée strictement nécessaire aux finalités poursuivies ou conformément aux obligations légales.'),
    _P('p', 'Sous réserve des dispositions légales applicables, chaque Utilisateur dispose notamment d\'un droit d\'accès, de rectification, de mise à jour, d\'effacement, d\'opposition, de limitation du traitement et, le cas échéant, de portabilité de ses données personnelles.'),
    _P('h', 'Données collectées'),
    _P('p', 'Dans le cadre de l\'utilisation de la Plateforme VigiRoutes, OYOP Multiservices & Transport est amenée à collecter et traiter différentes catégories de données à caractère personnel, notamment :'),
    _P('h', 'a) Données d\'identification'),
    _P('b', 'Nom et prénom ;'),
    _P('b', 'Numéro de téléphone ;'),
    _P('b', 'Adresse électronique (le cas échéant) ;'),
    _P('b', 'Photographie de profil (facultative) ;'),
    _P('p', 'Informations relatives au compte utilisateur.'),
    _P('h', 'b) Données de localisation'),
    _P('p', 'Afin de permettre la prise en charge des demandes d\'assistance, la Plateforme peut collecter :'),
    _P('b', 'La position GPS en temps réel ;'),
    _P('b', 'Les coordonnées géographiques du lieu d\'intervention ;'),
    _P('p', 'L\'historique des localisations liées aux interventions.'),
    _P('p', 'La géolocalisation n\'est activée que lorsque cela est nécessaire au fonctionnement des services proposés.'),
    _P('h', 'C) données relatives aux interventions'),
    _P('b', 'Historique des demandes d\'assistance ;'),
    _P('b', 'Nature des incidents signalés ;'),
    _P('b', 'Prestataires sollicités ;'),
    _P('b', 'Suivi des interventions ;'),
    _P('p', 'Évaluations et commentaires des utilisateurs.'),
    _P('h', 'd) Données financières'),
    _P('p', 'Lorsque certains services sont payants, la Plateforme peut traiter les informations relatives :'),
    _P('b', 'Au portefeuille électronique (wallet) ;'),
    _P('b', 'Aux crédits disponibles ;'),
    _P('b', 'Aux opérations de paiement ;'),
    _P('p', 'Aux historiques de transactions.'),
    _P('p', 'Les données bancaires sont exclusivement traitées par les prestataires de paiement agréés et ne sont pas conservées par la plateforme, sauf obligation légale contraire.'),
    _P('h', 'e) Données techniques'),
    _P('b', 'Adresse IP ;'),
    _P('b', 'Identifiant de l\'appareil ;'),
    _P('b', 'Système d\'exploitation ;'),
    _P('b', 'Identifiants Firebase ;'),
    _P('b', 'Journaux de connexion (logs) ;'),
    _P('b', 'Données de navigation ;'),
    _P('p', 'Informations relatives aux performances de l\'Application.'),
    _P('h', 'd) Durée de conservation'),
    _P('p', 'Conservation des données à caractère personnel'),
    _P('p', 'Les données à caractère personnel sont conservées pendant une durée n\'excédant pas celle strictement nécessaire à la réalisation des finalités pour lesquelles elles ont été collectées, conformément à la Loi n° 2013-450 du 19 juin 2013 relative à la protection des données à caractère personnel.'),
    _P('p', 'Toutefois, lorsque la conservation des données est imposée ou autorisée par une disposition légale, réglementaire, judiciaire ou administrative, notamment en matière de lutte contre le blanchiment de capitaux, le financement du terrorisme, de prévention de la fraude, de comptabilité, de fiscalité ou de preuve en justice, les données sont conservées pendant la durée prévue par les textes applicables.'),
    _P('p', 'À ce titre, lorsque la réglementation relative à la lutte contre le blanchiment de capitaux et le financement du terrorisme est applicable, les données et documents concernés peuvent être conservés pendant une durée maximale de dix (10) ans à compter de la cessation de la relation d\'affaires ou de la réalisation de l\'opération, conformément aux dispositions légales en vigueur.'),
    _P('p', 'À l\'expiration des délais de conservation applicables, les données sont supprimées, anonymisées ou archivées de manière sécurisée, conformément aux exigences de la réglementation en vigueur'),
    _P('p', 'Données de géolocalisation'),
    _P('p', 'Cependant uniquement pendant la durée nécessaire à la gestion de l\'intervention, puis suppression ou anonymisation, sauf obligation légale.'),
    _P('h', 'Base juridique des traitements'),
    _P('p', 'Les traitements de données reposent notamment sur :'),
    _P('b', 'Le consentement de l\'Utilisateur lorsque celui-ci est requis ;'),
    _P('b', 'L\'exécution des présentes Conditions Générales d\'Utilisation ;'),
    _P('b', 'Le respect des obligations légales et réglementaires applicables ;'),
    _P('p', 'L\'intérêt légitime de OYOP Multiservices & Transport, notamment pour assurer la sécurité, la maintenance, la prévention des fraudes et l\'amélioration des services.'),
    _P('h', 'Destinataires des données'),
    _P('p', 'Les données personnelles sont accessibles uniquement aux personnes habilitées dans la limite de leurs attributions, notamment :'),
    _P('b', 'Les équipes autorisées de OYOP Multiservices & Transport ;'),
    _P('b', 'Les prestataires de services routiers agréés ;'),
    _P('b', 'Les services de secours Partenaires, notamment le SAMU et, le cas échéant, les services d\'incendie et de secours (GSPM) ;'),
    _P('b', 'Les prestataires techniques intervenant dans l\'hébergement, la maintenance ou les services de notification ;'),
    _P('p', 'Les autorités administratives ou judiciaires compétentes lorsqu\'une obligation légale l\'impose.'),
    _P('p', 'Les données ne sont ni vendues ni cédées à des tiers à des fins commerciales sans le consentement préalable de l\'Utilisateur.'),
    _P('h', 'Durée de conservation'),
    _P('p', 'Les données personnelles sont conservées pendant une durée n\'excédant pas celle nécessaire à la réalisation des finalités pour lesquelles elles ont été collectées, sous réserve des obligations légales de conservation imposées par la réglementation en vigueur.'),
    _P('p', 'À l\'issue de ces délais, elles sont supprimées ou anonymisées, sauf lorsqu\'une conservation supplémentaire est exigée par la loi ou nécessaire à la défense des droits de la Plateforme.'),
    _P('h', 'Sécurité des données'),
    _P('p', 'OYOP Multiservices & Transport met en œuvre des mesures techniques et organisationnelles appropriées afin d\'assurer la confidentialité, l\'intégrité, la disponibilité et la résilience des données personnelles contre toute perte, destruction, altération, divulgation ou accès non autorisé.'),
    _P('p', 'Toutefois, aucun système informatique ne pouvant garantir une sécurité absolue, l\'Utilisateur reconnaît que le risque zéro n\'existe pas sur Internet.'),
    _P('h', 'Droits des utilisateurs'),
    _P('p', 'Conformément à la législation ivoirienne applicable en matière de protection des données à caractère personnel, tout Utilisateur dispose des droits suivants :'),
    _P('b', 'Droit d\'information ;'),
    _P('b', 'Droit d\'accès à ses données personnelles ;'),
    _P('b', 'Droit de rectification des données inexactes ou incomplètes ;'),
    _P('b', 'Droit à l\'effacement des données lorsque les conditions légales sont réunies ;'),
    _P('b', 'Droit à la limitation du traitement ;'),
    _P('b', 'Droit d\'opposition au traitement dans les cas prévus par la loi ;'),
    _P('b', 'Droit de retirer son consentement lorsque le traitement repose sur celui-ci ;'),
    _P('p', 'Droit de solliciter la suppression de son compte utilisateur.'),
    _P('p', 'Ces droits peuvent être exercés à tout moment en adressant une demande accompagnée d\'un justificatif d\'identité auprès du Délégué à la Protection des Données (DPO), lorsqu\'un tel délégué a été désigné.'),
    _P('h', 'Finalités du traitement'),
    _P('p', 'Les données personnelles sont collectées et traitées exclusivement pour les finalités suivantes :'),
    _P('b', 'Assurer la création et la gestion des comptes utilisateurs ;'),
    _P('b', 'Permettre la mise en relation entre les usagers, les prestataires et les services de secours ;'),
    _P('b', 'Transmettre les demandes d\'assistance aux Partenaires compétents ;'),
    _P('b', 'Assurer la géolocalisation des interventions ;'),
    _P('b', 'Améliorer la qualité et la continuité des services proposés ;'),
    _P('b', 'Envoyer des notifications, alertes et informations relatives aux interventions ;'),
    _P('b', 'Gérer les paiements et les portefeuilles électroniques ;'),
    _P('b', 'Prévenir les fraudes, abus et actes de cyber malveillance ;'),
    _P('b', 'Assurer la sécurité des systèmes d\'information ;'),
    _P('b', 'Produire des statistiques anonymisées destinées à améliorer les performances de la Plateforme ;'),
    _P('p', 'Satisfaire aux obligations légales, réglementaires ou judiciaires applicables.'),
    _P('h', 'Réclamations'),
    _P('p', 'Tout Utilisateur estimant que le traitement de ses données personnelles n\'est pas conforme à la réglementation applicable peut introduire une réclamation auprès de l\'autorité ivoirienne compétente en matière de protection des données à caractère personnel, sans préjudice de tout autre recours administratif ou judiciaire.'),
    _P('p', 'Exercice des droits des utilisateurs'),
    _P('p', 'Pour exercer ses droits relatifs à la protection de ses données à caractère personnel (accès, rectification, suppression, opposition, limitation ou tout autre droit reconnu par la réglementation applicable), l’Utilisateur peut adresser une demande au Responsable du traitement ou, le cas échéant, au Délégué à la Protection des Données (DPO) à l’adresse suivante :'),
    _P('p', 'privacy@vigiroutes.com'),
    _P('p', 'Toute demande devra, si nécessaire, permettre de vérifier l’identité du demandeur afin d’éviter tout accès non autorisé aux données personnelles.'),
    _P('h', 'COOKIES, TRACEURS ET TECHNOLOGIES SIMILAIRES'),
    _P('h', 'Principe'),
    _P('p', 'Afin d\'assurer le bon fonctionnement de la Plateforme VigiRoutes, d\'améliorer l\'expérience utilisateur, de garantir la sécurité des services et d\'optimiser les performances de ses applications, OYOP Multiservices & Transport utilise des cookies, des traceurs, des kits de développement logiciel (SDK) ainsi que d\'autres technologies similaires.'),
    _P('p', 'Ces technologies permettent notamment d\'identifier les équipements utilisés, de sécuriser les connexions, d\'analyser l\'utilisation de la Plateforme et de fournir certaines fonctionnalités essentielles.'),
    _P('h', 'Cookies et traceurs strictement nécessaires'),
    _P('p', 'Ces cookies ou traceurs sont indispensables au fonctionnement de la Plateforme. Ils permettent notamment :'),
    _P('b', 'L\'authentification des utilisateurs ;'),
    _P('b', 'La gestion des sessions de connexion ;'),
    _P('b', 'La sécurisation des comptes utilisateurs ;'),
    _P('b', 'La mémorisation des préférences essentielles ;'),
    _P('b', 'Le fonctionnement des services d\'assistance et de géolocalisation ;'),
    _P('p', 'La protection contre les accès frauduleux.'),
    _P('p', 'Ces technologies ne peuvent être désactivées lorsqu\'elles sont indispensables au fonctionnement des services.'),
    _P('h', 'Cookies analytiques et statistiques'),
    _P('p', 'VigiRoutes utilise des outils d\'analyse permettant de mesurer l\'utilisation de la Plateforme afin d\'améliorer continuellement ses services.'),
    _P('p', 'Les données recueillies sont utilisées notamment pour :'),
    _P('b', 'Mesurer la fréquentation des applications ;'),
    _P('b', 'Analyser les parcours utilisateurs ;'),
    _P('b', 'Identifier les fonctionnalités les plus utilisées ;'),
    _P('b', 'Détecter les erreurs techniques ;'),
    _P('p', 'Améliorer les performances de la Plateforme.'),
    _P('p', 'À cette fin, VigiRoutes peut notamment utiliser :'),
    _P('b', 'Google Analytics 4 (GA4) ;'),
    _P('p', 'Firebase Analytics.'),
    _P('p', 'Les informations recueillies sont, dans la mesure du possible, agrégées ou pseudonymisées.'),
    _P('h', 'Services Firebase'),
    _P('p', 'Les applications VigiRoutes utilisent plusieurs services fournis par Firebase, notamment :'),
    _P('b', 'Firebase Authentication, pour l\'authentification des utilisateurs ;'),
    _P('b', 'Firebase Cloud Messaging (FCM), pour l\'envoi des notifications relatives aux demandes d\'assistance, aux interventions et aux informations importantes ;'),
    _P('b', 'Firebase Analytics, pour les statistiques d\'utilisation ;'),
    _P('p', 'Firebase Crashlytics, pour la détection, le diagnostic et la correction des anomalies techniques.'),
    _P('p', 'Ces services peuvent collecter certaines données techniques telles que :'),
    _P('b', 'L\'identifiant unique de l\'appareil ;'),
    _P('b', 'L\'adresse IP ;'),
    _P('b', 'Le système d\'exploitation ;'),
    _P('b', 'La version de l\'application ;'),
    _P('b', 'Les journaux d\'événements techniques ;'),
    _P('p', 'Les informations relatives aux performances de l\'application.'),
    _P('h', 'Données de géolocalisation'),
    _P('p', 'Avec le consentement de l\'Utilisateur lorsque celui-ci est requis par la réglementation, la Plateforme collecte les données de localisation nécessaires à :'),
    _P('b', 'La transmission des demandes d\'assistance ;'),
    _P('b', 'L\'identification du prestataire le plus proche ;'),
    _P('b', 'La coordination des interventions ;'),
    _P('p', 'Le suivi en temps réel des opérations d\'assistance.'),
    _P('p', 'La géolocalisation est limitée aux besoins du service et n\'est activée que dans les conditions prévues par les paramètres de l\'Application ou du terminal de l\'Utilisateur.'),
    _P('h', 'Consentement'),
    _P('p', 'Lorsque la réglementation applicable l\'exige, l\'installation ou l\'utilisation des cookies et traceurs non strictement nécessaires est subordonnée au consentement préalable de l\'Utilisateur.'),
    _P('p', 'L\'Utilisateur peut, à tout moment, retirer ou modifier son consentement depuis les paramètres de son navigateur, de son appareil ou de l\'Application, lorsque cette fonctionnalité est disponible.'),
    _P('h', 'Durée de conservation'),
    _P('p', 'Les cookies, identifiants techniques et autres traceurs sont conservés pendant une durée n\'excédant pas celle autorisée par la réglementation applicable ou nécessaire aux finalités poursuivies.'),
    _P('p', 'À l\'expiration de cette durée, ils sont supprimés, anonymisés ou archivés conformément aux obligations légales.'),
    _P('h', 'Protection des données'),
    _P('p', 'Les informations collectées au moyen des cookies et technologies similaires sont traitées conformément à la Politique de confidentialité de VigiRoutes et à la législation ivoirienne relative à la protection des données à caractère personnel.'),
    _P('p', 'OYOP Multiservices & Transport met en œuvre les mesures techniques et organisationnelles appropriées afin d\'assurer la confidentialité, l\'intégrité et la sécurité des données collectées.'),
    _P('p', 'Pour toute question relative aux cookies, aux technologies de suivi ou au traitement des données personnelles, l\'Utilisateur peut contacter le service chargé de la protection des données à l\'adresse électronique indiquée dans la Politique de confidentialité.'),
];
