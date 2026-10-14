import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_stand_zeile.dart';
import 'package:automation_app/core/backend/app_version.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:material_ui/material_ui.dart';

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
  const AnwendungsInfo({required this.ansicht, super.key});

  /// Stand der Aktualisierung; `null` ohne Dienst (Widget-Tests).
  final AktualisierungsAnsicht? ansicht;

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
        AktualisierungsStandZeile(ansicht: ansicht),
        ..._baustand(context, version),
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
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
    ];
  }
}
