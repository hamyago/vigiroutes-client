import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Service de partage de position de sécurité.
///
/// Envoie un SMS pré-rempli à un proche avec :
///   - Position GPS (lien Google Maps)
///   - Nom du prestataire
///   - Heure estimée d'arrivée
class SafetyShareService {
  SafetyShareService._();
  static final SafetyShareService instance = SafetyShareService._();

  /// Ouvre l'app SMS avec un message de sécurité pré-rempli.
  ///
  /// [phone]         : numéro du proche (format local ou international)
  /// [latitude]      : position GPS de l'utilisateur
  /// [longitude]     : position GPS de l'utilisateur
  /// [providerName]  : nom du prestataire qui intervient
  /// [serviceType]   : type de service (ex: "Mécanique")
  /// [etaMinutes]    : estimation d'arrivée en minutes (null si inconnu)
  ///
  /// Retourne true si le SMS a pu être ouvert, false sinon.
  Future<bool> sendSafetyMessage({
    required String phone,
    required double latitude,
    required double longitude,
    required String providerName,
    required String serviceType,
    int? etaMinutes,
  }) async {
    final mapsLink = 'https://maps.google.com/?q=$latitude,$longitude';

    final etaText = etaMinutes != null
        ? '\n⏱ Arrivée estimée dans $etaMinutes min'
        : '';

    final cleanPhone = _cleanPhone(phone);

    final body = '🛡️ VigiRoutes — Alerte sécurité\n\n'
        'Je viens de commander un service de dépannage ($serviceType).\n'
        'Voici ma position GPS en temps réel :\n'
        '📍 $mapsLink\n\n'
        '🔧 Prestataire : $providerName'
        '$etaText\n\n'
        'Ce message a été envoyé automatiquement via VigiRoutes.';

    // Sur web : sms: fonctionne sur mobile Chrome mais pas desktop
    // Sur mobile natif : ouvre directement l'app SMS
    final uri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: {'body': body},
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return true;
    }

    // Fallback web desktop : WhatsApp web
    if (kIsWeb) {
      final waUri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(body)}',
      );
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return true;
      }
    }

    return false;
  }

  /// Nettoie le numéro de téléphone :
  /// supprime espaces, tirets, parenthèses.
  /// Ajoute le préfixe +225 si c'est un numéro ivoirien à 10 chiffres.
  String _cleanPhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]+'), '');

    // Déjà au format international
    if (cleaned.startsWith('+')) return cleaned;

    // Numéro ivoirien sans indicatif
    if (cleaned.length == 10 && !cleaned.startsWith('00')) {
      return '+225$cleaned';
    }

    // Avec 00
    if (cleaned.startsWith('00')) {
      return '+${cleaned.substring(2)}';
    }

    return cleaned;
  }
}
