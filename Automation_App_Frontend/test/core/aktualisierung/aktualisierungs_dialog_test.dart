import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_fehler_art.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/presentation/browser_oeffner.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierung_cubit.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog_inhalt.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/selbst_herunterladen_knopf.dart';
import 'package:automation_app/core/general_widgets/aktualisieren_button.dart';
import 'package:automation_app/core/general_widgets/drawer/sidebar_update_hinweis.dart';
import 'package:automation_app/core/general_widgets/hinweis_zeile.dart';
import 'package:automation_app/core/general_widgets/schritt_anzeige.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'aktualisierung_doubles.dart';
import 'aktualisierungs_dialog_testaufbau.dart';

/// Der Dialog „App aktualisieren“ in jedem Zustand der abgenommenen Vorschau
/// (#196, 2a–2e) — Wortlaut, Knöpfe und was sie auslösen.
void main() {
  late List<List<String>> gestartet;

  setUp(() {
    gestartet = [];
    BrowserOeffner.starte = (programm, argumente) async =>
        gestartet.add([programm, ...argumente]);
  });
  tearDown(BrowserOeffner.zuruecksetzen);

  SchrittAnzeige schritte(WidgetTester tester) =>
      tester.widget<SchrittAnzeige>(find.byType(SchrittAnzeige));

  testWidgets('2a verfügbar: Hauptknopf lädt, Rückfallweg öffnet die Datei', (
    tester,
  ) async {
    final aufbau = await oeffneDialog(
      tester,
      standMit(AktualisierungsZustand.verfuegbar),
    );

    expect(find.text('App aktualisieren'), findsOneWidget);
    expect(find.text('Version 1.4.0 ist verfügbar.'), findsOneWidget);
    for (final schritt in ['Herunterladen', 'Neu starten', 'Fertig']) {
      expect(find.text(schritt), findsOneWidget);
    }
    expect(schritte(tester).aktiv, isNull);
    expect(find.text(AktualisierungsDialogInhalt.datenBleiben), findsOneWidget);
    expect(
      find.text(
        'Das Herunterladen läuft im Hintergrund – Sie können dabei '
        'weiterarbeiten.',
      ),
      findsOneWidget,
    );
    expect(find.text('Später'), findsOneWidget);

    await tester.tap(find.byKey(SelbstHerunterladenKnopf.schluessel));
    await tester.pump();
    expect(gestartet, [
      ['rundll32', 'url.dll,FileProtocolHandler', setupAdresse],
    ], reason: 'ohne Shell, die Adresse als ein Argument');

    await tester.tap(
      find.byKey(AktualisierungsDialogInhalt.jetztAktualisierenSchluessel),
    );
    await zeigeBild(tester);
    expect(aufbau.repository.aufrufe, contains('herunterladen'));
  });

  testWidgets('2a ohne Download-Adresse: kein Rückfallweg, Später rechts', (
    tester,
  ) async {
    await oeffneDialog(
      tester,
      standMit(AktualisierungsZustand.verfuegbar, downloadUrl: null),
    );

    expect(find.byKey(SelbstHerunterladenKnopf.schluessel), findsNothing);
    expect(find.byKey(AktualisierungsDialog.spaeterSchluessel), findsOneWidget);
  });

  testWidgets('2b lädt: Fortschritt, schließen lässt im Hintergrund laden', (
    tester,
  ) async {
    final aufbau = await oeffneDialog(
      tester,
      standMit(AktualisierungsZustand.laedt, geladen: 54 * 1024 * 1024),
    );

    expect(find.text('Version 1.4.0 wird heruntergeladen.'), findsOneWidget);
    expect(schritte(tester).aktiv, 0);
    expect(find.text('54 von 92 MB'), findsOneWidget);
    expect(
      find.text(
        'Sie können weiterarbeiten. Dieses Fenster lässt sich schließen. '
        'Den Stand sehen Sie auch unten in der Seitenleiste.',
      ),
      findsOneWidget,
    );
    expect(find.text('Laden abbrechen'), findsOneWidget);

    await tester.tap(find.byKey(AktualisierungsDialog.schliessenSchluessel));
    await zeigeBild(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(aufbau.takt.offen, 1, reason: 'Das Abfragen läuft weiter.');
  });

  testWidgets('2b „Laden abbrechen“ bricht im Dienst ab', (tester) async {
    final aufbau = await oeffneDialog(
      tester,
      standMit(AktualisierungsZustand.laedt),
    );
    aufbau.repository.abbrueche.add(
      ok(standMit(AktualisierungsZustand.verfuegbar)),
    );

    await tester.tap(
      find.byKey(AktualisierungsDialog.ladenAbbrechenSchluessel),
    );
    await zeigeBild(tester);

    expect(aufbau.repository.aufrufe, contains('abbrechen'));
    expect(find.text('Version 1.4.0 ist verfügbar.'), findsOneWidget);
  });

  testWidgets('2c bereit, dann 2e: ohne Knöpfe, bis die App zugeht', (
    tester,
  ) async {
    final aufbau = await oeffneDialog(
      tester,
      standMit(AktualisierungsZustand.bereit, geladen: 92 * 1024 * 1024),
    );

    expect(find.text('Version 1.4.0 ist bereit.'), findsOneWidget);
    expect(schritte(tester).erledigt, 1);
    expect(schritte(tester).aktiv, 1);
    expect(
      find.text(
        'Die App wird kurz geschlossen und startet von selbst neu '
        '(ca. 1 Minute).',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Bitte speichern Sie offene Eingaben vorher.'),
      findsOneWidget,
    );
    expect(find.text(AktualisierungsDialogInhalt.datenBleiben), findsOneWidget);
    expect(find.text('Später'), findsOneWidget);

    await tester.tap(find.byKey(AktualisierungsDialog.neuStartenSchluessel));
    await zeigeBild(tester);

    expect(find.text('Die App wird jetzt geschlossen …'), findsOneWidget);
    expect(
      find.text(
        'Sie startet in etwa einer Minute von selbst wieder – Sie müssen '
        'nichts tun.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Falls die App nach zwei Minuten nicht wieder da ist, öffnen Sie sie '
        'wie gewohnt über das Symbol.',
      ),
      findsOneWidget,
    );
    expect(dialogKnoepfe(), findsNothing);
    expect(aufbau.repository.aufrufe, contains('installieren'));

    // Daneben tippen schließt nicht mehr — der Installer läuft schon.
    await tester.tapAt(const Offset(5, 5));
    await zeigeBild(tester);
    expect(find.text('Die App wird jetzt geschlossen …'), findsOneWidget);

    expect(aufbau.beendet, 0, reason: 'erst nach der Pause');
    aufbau.takt.freigeben();
    await tester.pump();
    expect(aufbau.beendet, 1);
  });

  testWidgets('Testmodus: Dialog schließt, Rückmeldung statt Beenden', (
    tester,
  ) async {
    final aufbau = await oeffneDialog(
      tester,
      standMit(AktualisierungsZustand.bereit),
      testmodus: true,
    );

    await tester.tap(find.byKey(AktualisierungsDialog.neuStartenSchluessel));
    await zeigeBild(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(AktualisierungCubit.testmodusHinweis), findsOneWidget);
    expect(aufbau.beendet, 0);

    // Die Rückmeldung (Hinweis) läuft nach fünf Sekunden ab.
    await tester.pump(const Duration(seconds: 6));
  });

  group('2d Fehler — ruhig, nicht rot', () {
    testWidgets('Verbindung: der kurze Satz zur Internetverbindung', (
      tester,
    ) async {
      final aufbau = await oeffneDialog(
        tester,
        standMit(
          AktualisierungsZustand.fehler,
          meldung:
              'Der Download wurde unterbrochen — vermutlich ist die '
              'Internetverbindung abgerissen. Bitte noch einmal versuchen.',
          fehlerArt: AktualisierungsFehlerArt.verbindung,
        ),
      );

      expect(
        find.text('Version 1.4.0 konnte nicht heruntergeladen werden.'),
        findsOneWidget,
      );
      expect(
        find.text('Meist fehlt nur kurz die Internetverbindung.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Es wurde nichts verändert. Sie können wie gewohnt weiterarbeiten.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(SelbstHerunterladenKnopf.schluessel), findsOneWidget);
      expect(
        find.byTooltip('Lädt die neue Version über Ihren Browser herunter'),
        findsOneWidget,
        reason: 'Er öffnet die Setup-Datei, nicht die Seite der Version.',
      );
      expect(schritte(tester).aktiv, isNull);

      final fehlerfarbe = Theme.of(tester.element(find.byType(AlertDialog)))
          .colorScheme
          .error;
      for (final zeile in tester.widgetList<HinweisZeile>(
        find.byType(HinweisZeile),
      )) {
        expect(zeile.farbe, isNot(fehlerfarbe));
      }

      // Der Dienst prüft neu (danach wieder „verfügbar“) und lädt.
      aufbau.repository.pruefungen.add(
        ok(standMit(AktualisierungsZustand.verfuegbar)),
      );
      aufbau.repository.downloads.add(
        ok(standMit(AktualisierungsZustand.laedt)),
      );
      await tester.tap(
        find.byKey(AktualisierungsDialog.erneutVersuchenSchluessel),
      );
      await zeigeBild(tester);
      expect(
        aufbau.repository.aufrufe,
        containsAllInOrder(['pruefen', 'herunterladen']),
      );
      expect(find.text('Version 1.4.0 wird heruntergeladen.'), findsOneWidget);
    });

    testWidgets('Prüfung: die Datei wird nicht verwendet', (tester) async {
      await oeffneDialog(
        tester,
        standMit(
          AktualisierungsZustand.fehler,
          meldung:
              'Die heruntergeladene Datei stimmt nicht mit der '
              'veröffentlichten überein und wurde gelöscht.',
          fehlerArt: AktualisierungsFehlerArt.pruefung,
        ),
      );

      expect(
        find.text(
          'Die Datei kam nicht vollständig an und wird nicht verwendet.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Meist fehlt nur kurz die Internetverbindung.'),
        findsNothing,
      );
    });

    testWidgets('sonst: der Satz des Dienstes, „hat nicht geklappt“', (
      tester,
    ) async {
      const satz =
          'Die Datei ließ sich nicht speichern (ist die Festplatte voll?).';
      await oeffneDialog(
        tester,
        standMit(
          AktualisierungsZustand.fehler,
          meldung: satz,
          fehlerArt: AktualisierungsFehlerArt.sonstig,
        ),
      );

      expect(find.text(satz), findsOneWidget);
      expect(
        find.text('Die Aktualisierung auf Version 1.4.0 hat nicht geklappt.'),
        findsOneWidget,
        reason: 'auch der Start des Setups fällt unter sonstig',
      );
      expect(
        find.text('Version 1.4.0 konnte nicht heruntergeladen werden.'),
        findsNothing,
      );
    });

    testWidgets('ohne fehlerArt der Satz des Dienstes, ungedeutet', (
      tester,
    ) async {
      // Früher hätte „Internetverbindung“ im Satz den kurzen Satz ausgelöst.
      const satz =
          'Der Download wurde unterbrochen — vermutlich ist die '
          'Internetverbindung abgerissen.';
      await oeffneDialog(
        tester,
        standMit(AktualisierungsZustand.fehler, meldung: satz),
      );

      expect(find.text(satz), findsOneWidget);
      expect(
        find.text('Meist fehlt nur kurz die Internetverbindung.'),
        findsNothing,
      );
    });
  });

  test('die Schlüssel heißen wie in test_driver/README.md', () {
    // E2E-Suite und Marionette tippen über diese Namen; ändert sich einer,
    // finden sie den Knopf nicht mehr. „Jetzt neu starten“ startet außerhalb
    // des Testmodus den Installer und schließt die App.
    expect(
      SidebarUpdateHinweis.schluessel,
      const ValueKey('aktualisierung-hinweis'),
    );
    expect(
      AktualisierenButton.schluessel,
      const ValueKey('aktualisierung-oeffnen'),
    );
    expect(
      AktualisierungsDialogInhalt.jetztAktualisierenSchluessel,
      const ValueKey('aktualisierung-jetzt-aktualisieren'),
    );
    expect(
      AktualisierungsDialog.neuStartenSchluessel,
      const ValueKey('aktualisierung-neu-starten'),
    );
    expect(
      AktualisierungsDialog.erneutVersuchenSchluessel,
      const ValueKey('aktualisierung-erneut-versuchen'),
    );
  });
}
