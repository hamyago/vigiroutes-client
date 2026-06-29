import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Joue une alarme sonore puis une annonce vocale (français) lorsque le
/// prestataire accepte la demande et se met en route vers l'utilisateur.
///
/// - L'audio provient de `assets/raw/alarm.wav` (déclaré dans pubspec.yaml).
///   `audioplayers` préfixe automatiquement `assets/`, donc on passe
///   `AssetSource('raw/alarm.wav')`.
/// - La voix utilise le moteur TTS natif du téléphone en `fr-FR`
///   (fonctionne hors-ligne une fois le pack de langue installé).
///
/// Le déclenchement est idempotent : une seule annonce par intervention
/// (voir [reset]), pour éviter de répéter le message à chaque tick WebSocket.
class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _announcedOnTheWay = false;

  Future<void> _ensureTts() async {
    if (_ttsReady) return;
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(0.5); // débit posé et intelligible
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    } catch (e) {
      debugPrint('[Alert] init TTS: $e');
    }
  }

  /// Alarme + annonce « le prestataire est en route ».
  /// Ne se déclenche qu'une fois tant que [reset] n'a pas été appelé.
  Future<void> providerOnTheWay({String? providerName}) async {
    if (_announcedOnTheWay) return;
    _announcedOnTheWay = true;

    // 1) Alarme sonore
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource('raw/alarm.wav'), volume: 1.0);
    } catch (e) {
      debugPrint('[Alert] alarme: $e');
    }

    // 2) Laisser l'alarme retentir ~2 s, puis couper avant de parler
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    try {
      await _player.stop();
    } catch (_) {}

    // 3) Annonce vocale en français
    await _ensureTts();
    final who = (providerName != null && providerName.trim().isNotEmpty)
        ? providerName.trim()
        : 'Un prestataire';
    final phrase = '$who a accepté votre demande et se dirige vers vous '
        'pour vous dépanner. Veuillez rester à proximité de votre véhicule.';
    try {
      await _tts.speak(phrase);
    } catch (e) {
      debugPrint('[Alert] TTS speak: $e');
    }
  }

  /// Réarme l'alerte pour une prochaine intervention
  /// (à appeler quand on quitte l'écran de suivi).
  void reset() => _announcedOnTheWay = false;

  /// Coupe immédiatement son et voix (ex. annulation).
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _tts.stop();
  }
}
