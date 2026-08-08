import 'package:automation_app/core/aktualisierung/aktualisierungs_ergebnis.dart';
import 'package:automation_app/core/backend/app_version.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/ueber_anwendung_dialog.dart';
import 'package:flutter/material.dart';

/// Zeigt die laufende Version — ausgeschrieben, nicht als `v1.0.0`.
///
/// Beantwortet die Frage, die bei jeder Rückmeldung als Erstes kommt: „welchen
/// Stand haben Sie eigentlich?". Deshalb steht hier das Wort „Version" und
/// nichts, was nach Entwicklerkürzel aussieht; der Commit steht im Dialog
/// dahinter, wo er niemanden verwirrt.
class VersionBadge extends StatelessWidget {
  const VersionBadge({this.stand, super.key});

  /// Ergebnis der Update-Prüfung; wird an den Dialog durchgereicht.
  final AktualisierungsErgebnis? stand;

  @override
  Widget build(BuildContext context) {
    // In Widget-Tests läuft kein Dienst, also ist auch nichts registriert.
    if (!getIt.isRegistered<AppVersion>()) return const SizedBox.shrink();

    final version = getIt<AppVersion>();
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Über diese Anwendung',
      child: InkWell(
        onTap: () => UeberAnwendungDialog.zeigen(context, stand),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'Version ${version.anzeige}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
