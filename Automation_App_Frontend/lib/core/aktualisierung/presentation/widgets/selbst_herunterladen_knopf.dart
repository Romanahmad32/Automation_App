import 'package:automation_app/core/aktualisierung/presentation/browser_oeffner.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:material_ui/material_ui.dart';

/// „Lieber selbst herunterladen“ (2a, 2d) — der Rückfallweg: öffnet die
/// Setup-Datei der neuen Version direkt im Browser (`downloadUrl`), nicht die
/// Release-Seite. Leise gesetzt, damit er neben dem Hauptknopf nicht wie eine
/// gleichwertige Wahl aussieht.
class SelbstHerunterladenKnopf extends StatelessWidget {
  /// Öffnet nur den Browser — die Marionette-Sperre braucht ihn nicht.
  static const Key schluessel = ValueKey('aktualisierung-selbst-herunterladen');

  /// Öffnet [BrowserOeffner] nichts — eine Adresse, die nicht nach GitHub
  /// führt, oder ein Start, der nicht ging —, soll der Anwalt das lesen,
  /// statt vergeblich auf den Browser zu warten.
  static const String nichtGeoeffnet =
      'Der Download ließ sich nicht im Browser öffnen. Die Setup-Datei finden '
      'Sie auch auf der Seite der Version bei GitHub.';

  const SelbstHerunterladenKnopf({required this.adresse, super.key});

  final String adresse;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Lädt die neue Version über Ihren Browser herunter',
      child: TextButton.icon(
        key: schluessel,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: () => _oeffne(context),
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Lieber selbst herunterladen'),
      ),
    );
  }

  Future<void> _oeffne(BuildContext context) async {
    // Vor dem await gefasst — danach braucht der Handle den Kontext nicht mehr.
    final rueckmeldung = Rueckmeldung.von(context);
    if (!await BrowserOeffner.oeffne(adresse)) {
      rueckmeldung.fehler(nichtGeoeffnet);
    }
  }
}
