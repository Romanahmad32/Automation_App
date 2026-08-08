import 'package:automation_app/core/aktualisierung/neue_version.dart';
import 'package:automation_app/core/aktualisierung/release_seite_oeffnen.dart';
import 'package:flutter/material.dart';

/// Öffnet die Release-Seite, von der die Setup-Datei geladen wird.
///
/// Die Anwendung lädt und installiert bewusst nicht selbst: nur der Installer
/// schließt eine laufende Instanz sauber und lässt die Daten unter `%APPDATA%`
/// unberührt.
class UpdateHerunterladenButton extends StatelessWidget {
  const UpdateHerunterladenButton({
    required this.neueVersion,
    this.danach,
    super.key,
  });

  final NeueVersion neueVersion;

  /// Wird nach dem Öffnen aufgerufen — im Dialog, um ihn zu schließen.
  final VoidCallback? danach;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {
        releaseSeiteOeffnen(neueVersion.seite);
        danach?.call();
      },
      icon: const Icon(Icons.download),
      label: const Text('Herunterladen'),
    );
  }
}
