import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/letzte_aktualisierung.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierung_cubit.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_dialog_phase.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aktualisierung_doubles.dart';

/// Der Ablauf der Aktualisierung aus der App heraus (#196): Prüfen beim
/// Start, Abfragen nur während des Ladens, Ablehnungen als Meldung, und nach
/// „Jetzt neu starten“ das Beenden — außer im Testmodus.
void main() {
  late CubitAufbau aufbau;

  setUp(() => aufbau = CubitAufbau());
  tearDown(() => aufbau.cubit.close());

  group('beim Start', () {
    test(
      'holt erst den Stand, dann lässt er prüfen — einmal je Sitzung',
      () async {
        await aufbau.cubit.beimStart();
        await aufbau.cubit.beimStart();

        expect(aufbau.repository.aufrufe, ['stand', 'pruefen']);
        expect(aufbau.cubit.state.updateInSicht, isTrue);
      },
    );

    test(
      'ein stummer Dienst heißt „konnte nicht nachsehen“, ohne Meldung',
      () async {
        aufbau.repository.staende.add(abgelehnt('Dienst antwortet nicht.'));
        aufbau.repository.pruefungen.add(abgelehnt('Dienst antwortet nicht.'));

        await aufbau.cubit.beimStart();

        expect(aufbau.cubit.state.dienstStumm, isTrue);
        expect(aufbau.cubit.state.stand, isNull);
        expect(aufbau.cubit.state.ablehnung, isNull);
      },
    );

    test('außerhalb des Ladens wird nicht abgefragt', () async {
      await aufbau.cubit.beimStart();
      await pumpeMikroaufgaben();

      expect(aufbau.takt.offen, 0);
    });
  });

  group('Herunterladen', () {
    test(
      'während laedt wird alle 500 ms abgefragt, bei bereit hört es auf',
      () async {
        aufbau.repository.downloads.add(
          ok(standMit(AktualisierungsZustand.laedt)),
        );
        aufbau.repository.staende
          ..add(ok(standMit(AktualisierungsZustand.laedt, geladen: 54 << 20)))
          ..add(ok(standMit(AktualisierungsZustand.bereit, geladen: 92 << 20)));

        await aufbau.cubit.herunterladen();
        await pumpeMikroaufgaben();
        expect(
          aufbau.cubit.state.dialogPhase,
          AktualisierungsDialogPhase.laedt,
        );
        expect(aufbau.takt.gewartet, [AktualisierungCubit.abfrageTakt]);

        await aufbau.takt.weiter();
        expect(aufbau.cubit.state.stand!.prozent, 58);
        expect(aufbau.takt.offen, 1, reason: 'lädt noch — weiter abfragen');

        await aufbau.takt.weiter();
        expect(aufbau.cubit.state.zustand, AktualisierungsZustand.bereit);
        expect(aufbau.takt.offen, 0, reason: 'bereit — Abfragen beendet');
        expect(aufbau.repository.zaehle('stand'), 2);
      },
    );

    test('Laden abbrechen beendet das Abfragen', () async {
      aufbau.repository.downloads.add(
        ok(standMit(AktualisierungsZustand.laedt)),
      );
      aufbau.repository.abbrueche.add(
        ok(standMit(AktualisierungsZustand.verfuegbar)),
      );
      await aufbau.cubit.herunterladen();
      await pumpeMikroaufgaben();

      await aufbau.cubit.abbrechen();
      await aufbau.takt.weiter();

      expect(aufbau.cubit.state.zustand, AktualisierungsZustand.verfuegbar);
      expect(aufbau.takt.offen, 0);
    });

    test('409 wird zur Meldung, der Stand neu geholt', () async {
      aufbau.repository.downloads.add(
        abgelehnt('Es ist keine neue Version bekannt.'),
      );

      await aufbau.cubit.herunterladen();

      expect(
        aufbau.cubit.state.ablehnung,
        'Es ist keine neue Version bekannt.',
      );
      expect(aufbau.cubit.state.arbeitet, isFalse);
      expect(aufbau.repository.aufrufe, ['herunterladen', 'stand']);
    });

    test('drei stumme Abfragen in Folge werden zur Meldung — einmal', () async {
      aufbau.repository.downloads.add(
        ok(standMit(AktualisierungsZustand.laedt)),
      );
      for (var i = 0; i < 4; i++) {
        aufbau.repository.staende.add(abgelehnt('Dienst antwortet nicht.'));
      }
      final meldungen = <String>[];
      final abo = aufbau.cubit.stream.listen((ansicht) {
        if (ansicht.ablehnung case final satz?) meldungen.add(satz);
      });
      addTearDown(abo.cancel);
      await aufbau.cubit.herunterladen();
      await pumpeMikroaufgaben();

      await aufbau.takt.weiter();
      await aufbau.takt.weiter();
      expect(
        aufbau.cubit.state.ablehnung,
        isNull,
        reason: 'erst zwei Aussetzer',
      );
      await aufbau.takt.weiter();

      expect(aufbau.cubit.state.ablehnung, 'Dienst antwortet nicht.');
      expect(aufbau.takt.offen, 1, reason: 'aufgegeben wird nicht');

      await aufbau.takt.weiter();
      expect(meldungen, [
        'Dienst antwortet nicht.',
      ], reason: 'der vierte Aussetzer meldet sich nicht noch einmal');
    });

    test(
      'nach der Meldung langsamer weiter, bis der Dienst wieder antwortet',
      () async {
        aufbau.repository.downloads.add(
          ok(standMit(AktualisierungsZustand.laedt)),
        );
        for (var i = 0; i < 3; i++) {
          aufbau.repository.staende.add(abgelehnt('Dienst antwortet nicht.'));
        }
        aufbau.repository.staende.add(
          ok(standMit(AktualisierungsZustand.bereit, geladen: 92 << 20)),
        );
        await aufbau.cubit.herunterladen();
        await pumpeMikroaufgaben();

        for (var i = 0; i < 3; i++) {
          await aufbau.takt.weiter();
        }
        expect(aufbau.takt.gewartet, [
          AktualisierungCubit.abfrageTakt,
          AktualisierungCubit.abfrageTakt,
          AktualisierungCubit.abfrageTakt,
          AktualisierungCubit.ruhigerTakt,
        ]);
        expect(aufbau.cubit.state.zustand, AktualisierungsZustand.laedt);

        await aufbau.takt.weiter();

        expect(
          aufbau.cubit.state.zustand,
          AktualisierungsZustand.bereit,
          reason: 'Ring und Balken frieren nicht ein',
        );
        expect(aufbau.takt.offen, 0, reason: 'bereit — Abfragen beendet');
      },
    );

    test('Erneut versuchen prüft erst und lädt dann', () async {
      aufbau.repository.downloads.add(
        ok(standMit(AktualisierungsZustand.laedt)),
      );

      await aufbau.cubit.erneutVersuchen();

      expect(aufbau.repository.aufrufe, ['pruefen', 'herunterladen']);
      expect(aufbau.cubit.state.zustand, AktualisierungsZustand.laedt);
    });

    test(
      'Erneut versuchen lädt nicht, wenn die Prüfung einen Fehler meldet',
      () async {
        aufbau.repository.pruefungen.add(
          ok(
            standMit(
              AktualisierungsZustand.fehler,
              meldung: 'Prüfsumme fehlt.',
            ),
          ),
        );

        await aufbau.cubit.erneutVersuchen();

        expect(aufbau.repository.aufrufe, ['pruefen']);
        expect(
          aufbau.cubit.state.dialogPhase,
          AktualisierungsDialogPhase.fehler,
        );
        expect(aufbau.cubit.state.arbeitet, isFalse);
      },
    );
  });

  group('Jetzt neu starten', () {
    test('zeigt 2e und beendet die App nach der Pause', () async {
      aufbau.repository.installationen.add(
        ok(standMit(AktualisierungsZustand.bereit)),
      );

      final laeuft = aufbau.cubit.installieren();
      await pumpeMikroaufgaben();
      expect(
        aufbau.cubit.state.dialogPhase,
        AktualisierungsDialogPhase.schliesst,
      );
      expect(aufbau.takt.gewartet, [AktualisierungCubit.schliessPause]);
      expect(aufbau.beendet, 0, reason: 'erst nach der Pause');

      await aufbau.takt.weiter();
      await laeuft;
      expect(aufbau.beendet, 1);
    });

    test('im Testmodus bleibt die App offen', () async {
      final testmodus = CubitAufbau(testmodus: true);
      addTearDown(testmodus.cubit.close);
      testmodus.repository.installationen.add(
        ok(standMit(AktualisierungsZustand.bereit)),
      );

      await testmodus.cubit.installieren();

      expect(testmodus.cubit.state.testmodusNeustart, isTrue);
      expect(testmodus.cubit.state.schliesstGerade, isFalse);
      expect(testmodus.takt.offen, 0);
      expect(testmodus.beendet, 0);
    });

    test(
      '409 mit Fehlerstand: der Satz steht im Dialog, nicht doppelt',
      () async {
        const satz =
            'Die heruntergeladene Datei ist unvollständig und wurde gelöscht.';
        aufbau.repository.installationen.add(abgelehnt(satz));
        aufbau.repository.staende.add(
          ok(standMit(AktualisierungsZustand.fehler, meldung: satz)),
        );

        await aufbau.cubit.installieren();

        expect(
          aufbau.cubit.state.dialogPhase,
          AktualisierungsDialogPhase.fehler,
        );
        expect(aufbau.cubit.state.ablehnung, isNull);
        expect(aufbau.beendet, 0);
      },
    );

    test('409 ohne Zustandswechsel wird zur Meldung', () async {
      const satz =
          'Die neue Version ist noch nicht vollständig heruntergeladen.';
      aufbau.repository.installationen.add(abgelehnt(satz));

      await aufbau.cubit.installieren();

      expect(aufbau.cubit.state.ablehnung, satz);
      expect(aufbau.cubit.state.schliesstGerade, isFalse);
      expect(aufbau.beendet, 0);
    });
  });

  group('Ergebnis der letzten Aktualisierung', () {
    const letzte = LetzteAktualisierung(
      zielVersion: '1.4.0',
      erfolgreich: true,
    );

    test('quittieren nimmt es heraus — auch aus späteren Antworten', () async {
      aufbau.repository.staende.add(
        ok(standMit(AktualisierungsZustand.aktuell, letzte: letzte)),
      );
      aufbau.repository.pruefungen.add(
        ok(standMit(AktualisierungsZustand.aktuell, letzte: letzte)),
      );

      await aufbau.cubit.auffrischen();
      expect(aufbau.cubit.state.stand!.letzteAktualisierung, letzte);

      await aufbau.cubit.ergebnisQuittieren();
      await aufbau.cubit.ergebnisQuittieren();
      await aufbau.cubit.pruefen();

      expect(aufbau.repository.quittungen, 1);
      expect(aufbau.cubit.state.stand!.letzteAktualisierung, isNull);
    });
  });
}
