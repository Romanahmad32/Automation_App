import 'package:automation_app/core/aktualisierung/aktualisierungs_ergebnis.dart';
import 'package:automation_app/core/backend/app_version.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:flutter/material.dart';

/// Welche Version läuft, und ob es eine neuere gibt.
///
/// Geschrieben für jemanden, der weder Versionsnummern noch Commits liest: die
/// Nummer steht groß, und daneben steht in Worten, was sie bedeutet. Der
/// Baustand für Rückfragen steht klein darunter — er ist für den Entwickler
/// und soll die Aussage darüber nicht verwässern.
///
/// Wird an zwei Stellen gezeigt: im Dialog hinter der Seitenleiste und im
/// Einstellungen-Reiter „Über". Die Seitenleiste startet eingeklappt, dort
/// findet sie also nur, wer sie aufklappt — in den Einstellungen sucht ein
/// Windows-Anwender von sich aus.
class AnwendungsInfo extends StatelessWidget {
  const AnwendungsInfo({required this.stand, super.key});

  final AktualisierungsErgebnis? stand;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final version = getIt.isRegistered<AppVersion>()
        ? getIt<AppVersion>()
        : const AppVersion(AppVersion.unbekannt);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Automation App', style: textTheme.titleMedium),
        const SizedBox(height: 4),
        SelectableText(
          'Version ${version.anzeige}',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        _stand(context),
        ..._baustand(context, version),
      ],
    );
  }

  Widget _stand(BuildContext context) {
    final aktuell = stand;
    if (aktuell == null) {
      return _zeile(
        context,
        Icons.hourglass_empty,
        'Es wird nachgesehen, ob eine neuere Version vorliegt …',
      );
    }
    if (!aktuell.geprueft) {
      return _zeile(
        context,
        Icons.cloud_off,
        'Es konnte nicht nachgesehen werden, ob eine neuere Version vorliegt. '
        'Meist fehlt dafür nur die Internetverbindung.',
      );
    }
    final neu = aktuell.neueVersion;
    if (neu == null) {
      return _zeile(
        context,
        Icons.check_circle,
        'Sie verwenden die neueste Version.',
        farbe: Theme.of(context).colorScheme.primary,
      );
    }
    return _zeile(
      context,
      Icons.new_releases,
      'Version ${neu.nummer} ist verfügbar.\n\n'
      'Laden Sie die Setup-Datei herunter und führen Sie sie aus. Ihre '
      'Vorgänge, Mandanten, Vorlagen und Einstellungen bleiben dabei erhalten.',
      farbe: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _zeile(
    BuildContext context,
    IconData symbol,
    String text, {
    Color? farbe,
  }) {
    final farbton = farbe ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(symbol, size: 20, color: farbton),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: farbton),
          ),
        ),
      ],
    );
  }

  /// Der Commit hinter dem `+`. Fehlt er (Entwicklungsbuild), entfällt die Zeile.
  List<Widget> _baustand(BuildContext context, AppVersion version) {
    final teile = version.roh.split('+');
    if (teile.length < 2 || teile[1].isEmpty) return const [];
    return [
      const SizedBox(height: 20),
      const Divider(height: 1),
      const SizedBox(height: 8),
      SelectableText(
        'Baustand für Rückfragen: ${teile[1]}',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    ];
  }
}
