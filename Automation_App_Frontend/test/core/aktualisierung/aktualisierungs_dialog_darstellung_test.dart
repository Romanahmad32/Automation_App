import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_fehler_art.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aktualisierung_doubles.dart';
import 'aktualisierungs_dialog_testaufbau.dart';

/// Der Dialog ist ~420 px breit; bei der Schriftstufe „Am größten“ (#57)
/// dürfen weder Schrittanzeige noch Knopfzeile überlaufen.
void main() {
  final faelle = <String, AktualisierungsStand>{
    '2a verfügbar': standMit(AktualisierungsZustand.verfuegbar),
    '2b lädt': standMit(AktualisierungsZustand.laedt, geladen: 54 << 20),
    '2c bereit': standMit(AktualisierungsZustand.bereit),
    // Der längste Satz steht nur bei „sonstig“ im Dialog.
    '2d Fehler': standMit(
      AktualisierungsZustand.fehler,
      meldung:
          'Version 1.4.0 ist erschienen, lässt sich aber nicht sicher prüfen, '
          'weil die Prüfsumme fehlt. Deshalb lädt die App sie nicht selbst.',
      fehlerArt: AktualisierungsFehlerArt.sonstig,
    ),
  };

  for (final MapEntry(key: name, value: stand) in faelle.entries) {
    testWidgets('$name läuft bei „Am größten“ nicht über', (tester) async {
      await oeffneDialog(
        tester,
        stand,
        theme: appTheme(Schriftstufe.amGroessten),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('2e läuft bei „Am größten“ nicht über', (tester) async {
    await oeffneDialog(
      tester,
      standMit(AktualisierungsZustand.bereit),
      theme: appTheme(Schriftstufe.amGroessten),
    );
    await tester.tap(find.byKey(AktualisierungsDialog.neuStartenSchluessel));
    await zeigeBild(tester);

    expect(find.text('Die App wird jetzt geschlossen …'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
