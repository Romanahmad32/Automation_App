import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_fehler_art.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/presentation/browser_oeffner.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/selbst_herunterladen_knopf.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aktualisierung_doubles.dart';
import 'aktualisierungs_dialog_testaufbau.dart';

/// Der Dialog „App aktualisieren“, wenn etwas nicht geht, das erst beim Klick
/// auffällt (#196): Der Dienst lehnt „Jetzt neu starten“ ab, oder die Adresse
/// für „Lieber selbst herunterladen“ führt nicht zu GitHub. In keinem Fall
/// geht die App zu, und nichts startet.
void main() {
  late List<List<String>> gestartet;

  setUp(() {
    gestartet = [];
    BrowserOeffner.starte = (programm, argumente) async =>
        gestartet.add([programm, ...argumente]);
  });
  tearDown(BrowserOeffner.zuruecksetzen);

  testWidgets('Setup sofort beendet (409, fehler): 2d statt 2e, App bleibt', (
    tester,
  ) async {
    final aufbau = await oeffneDialog(
      tester,
      standMit(AktualisierungsZustand.bereit),
    );
    const satz =
        'Das Installationsprogramm hat sich sofort wieder beendet — vielleicht '
        'läuft gerade schon eine Installation. Bitte in ein paar Minuten noch '
        'einmal versuchen.';
    aufbau.repository.installationen.add(abgelehnt(satz));
    aufbau.repository.staende.add(
      ok(
        standMit(
          AktualisierungsZustand.fehler,
          meldung: satz,
          fehlerArt: AktualisierungsFehlerArt.sonstig,
        ),
      ),
    );

    await tester.tap(find.byKey(AktualisierungsDialog.neuStartenSchluessel));
    await zeigeBild(tester);

    expect(find.text('Die App wird jetzt geschlossen …'), findsNothing);
    expect(
      find.text('Die Aktualisierung auf Version 1.4.0 hat nicht geklappt.'),
      findsOneWidget,
    );
    expect(find.text(satz), findsOneWidget);
    expect(
      find.text(
        'Es wurde nichts verändert. Sie können wie gewohnt weiterarbeiten.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(AktualisierungsDialog.erneutVersuchenSchluessel),
      findsOneWidget,
    );
    expect(
      aufbau.cubit.state.ablehnung,
      isNull,
      reason: 'der Satz steht im Dialog, nicht noch einmal als Rückmeldung',
    );
    expect(aufbau.takt.offen, 0, reason: 'keine Schließpause');
    expect(aufbau.beendet, 0);
  });

  testWidgets(
    'Entwicklungsumgebung (409, Zustand bleibt): Meldung, 2c bleibt',
    (tester) async {
      final aufbau = await oeffneDialog(
        tester,
        standMit(AktualisierungsZustand.bereit),
      );
      const satz = 'Installieren geht nur aus der installierten App.';
      aufbau.repository.installationen.add(abgelehnt(satz));

      await tester.tap(find.byKey(AktualisierungsDialog.neuStartenSchluessel));
      await zeigeBild(tester);

      expect(find.text('Version 1.4.0 ist bereit.'), findsOneWidget);
      expect(find.text('Die App wird jetzt geschlossen …'), findsNothing);
      expect(aufbau.cubit.state.ablehnung, satz, reason: 'als Rückmeldung');
      expect(aufbau.beendet, 0);
    },
  );

  testWidgets('eine Adresse außerhalb von GitHub öffnet nichts und sagt es', (
    tester,
  ) async {
    await oeffneDialog(
      tester,
      standMit(
        AktualisierungsZustand.verfuegbar,
        downloadUrl: 'https://example.invalid/Automation_App_Setup_1.4.0.exe',
      ),
    );

    await tester.tap(find.byKey(SelbstHerunterladenKnopf.schluessel));
    await zeigeBild(tester);

    expect(gestartet, isEmpty);
    expect(find.text(SelbstHerunterladenKnopf.nichtGeoeffnet), findsOneWidget);
  });
}
