// lib/shared/utils/snackbar_helper.dart
// ─────────────────────────────────────────────────────────────────────────────
// Helper global pour afficher des SnackBars proprement.
//
// PROBLÈME RÉSOLU : Flutter empile les SnackBars si on appelle
// showSnackBar() plusieurs fois sans fermer le précédent. Résultat :
// des "fantômes" restent visibles pendant la navigation entre écrans
// (surtout avec les FCM en rafale).
//
// SOLUTION : Appeler clearSnackBars() avant chaque affichage.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Affiche un SnackBar en nettoyant d'abord les SnackBars en cours.
/// Utilise ce helper partout au lieu de ScaffoldMessenger.showSnackBar()
/// pour éviter l'empilement visuel.
void showAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 3),
  bool isError   = false,
  bool isWarning = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  // 🔧 Élimine les SnackBars empilés avant d'afficher le nouveau.
  messenger.clearSnackBars();

  Color bg = backgroundColor ??
      (isError
          ? Colors.red.shade700
          : isWarning
              ? Colors.orange.shade700
              : Colors.grey.shade900);

  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: bg,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: action,
    ),
  );
}
