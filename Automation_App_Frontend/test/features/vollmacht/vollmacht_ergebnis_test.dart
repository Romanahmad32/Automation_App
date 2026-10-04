import 'dart:typed_data';

import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_vorschau.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_abschluss.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vollmacht_doubles.dart';

/// Übersicht und Kontrolle im Vollmacht-Dialog (§4.11, #164): die
/// Seitenvorschau, der Drucker und das Ergebnis, das nach dem Druck stehen
/// bleibt und sich nachsteuern lässt.
void main() {
  const referenz = '12/26 C05_GG-XY 1';
  late VollmachtRepositoryDouble dienst;
  late VollmachtVorgaengeDouble vorgaenge;

  Vorgang vorgang({
    String rechtsgebiet = 'Strafrecht',
    String abteilung = 'C05',
  }) => Vorgang(
    referenz: referenz,
    angefragtAm: DateTime(2026, 9, 1),
    rechtsgebiet: rechtsgebiet,
    abteilung: abteilung,
  );

  setUp(() {
    dienst = VollmachtRepositoryDouble()
      ..vorschau = VollmachtVorschau(
        status: VollmachtVorschauStatus.erstellt,
        pdf: Uint8List.fromList([37, 80, 68, 70]),
      );
    vorgaenge = VollmachtVorgaengeDouble()..bestand[referenz] = vorgang();
    DateiOeffner.oeffne = (_) async => true;
  });

  tearDown(DateiOeffner.zuruecksetzen);

  group('Seitenvorschau', () {
    test(
      'ist nach dem Öffnen fällig und entsteht zur vorbelegten Art',
      () async {
        final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
        await aufbau.cubit.starte(vorgang(), const []);
        expect(aufbau.cubit.state.vorschauFaellig, isTrue);

        await aufbau.cubit.erstelleVorschau();

        expect(dienst.vorschauAuftraege.single.art, VollmachtArt.strafsache);
        expect(
          aufbau.cubit.state.vorschau?.status,
          VollmachtVorschauStatus.erstellt,
        );
        expect(aufbau.cubit.state.vorschauFaellig, isFalse);
        expect(aufbau.cubit.state.vorschauVeraltet, isFalse);
      },
    );

    test(
      'eine geänderte Zeile macht sie veraltet, erzeugt sie aber nicht neu',
      () async {
        final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
        await aufbau.cubit.starte(vorgang(), const []);
        await aufbau.cubit.erstelleVorschau();

        final stand = aufbau.cubit.state;
        aufbau.cubit.aendereKopfdaten(
          stand.kopfdaten.copyWith(ort: 'Musterstadt'),
        );

        expect(aufbau.cubit.state.vorschauVeraltet, isTrue);
        expect(dienst.vorschauAuftraege, hasLength(1));

        await aufbau.cubit.erstelleVorschau();

        expect(dienst.vorschauAuftraege, hasLength(2));
        expect(dienst.vorschauAuftraege.last.kopfdaten.ort, 'Musterstadt');
        expect(aufbau.cubit.state.vorschauVeraltet, isFalse);
      },
    );

    test('gedruckt werden die Felder, nicht die veraltete Vorschau', () async {
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang(), const []);
      await aufbau.cubit.erstelleVorschau();
      aufbau.cubit.aendereKopfdaten(
        aufbau.cubit.state.kopfdaten.copyWith(ort: 'Musterstadt'),
      );

      await aufbau.cubit.drucke();

      expect(dienst.gedruckt.single.kopfdaten.ort, 'Musterstadt');
    });

    test(
      'ein zweiter Klick während der Erzeugung bestellt nichts doppelt',
      () async {
        final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
        await aufbau.cubit.starte(vorgang(), const []);

        final erste = aufbau.cubit.erstelleVorschau();
        await aufbau.cubit.erstelleVorschau();
        await erste;

        expect(dienst.vorschauAuftraege, hasLength(1));
      },
    );

    test('eine Vorschau, die während des Drucks eintrifft, stört das Ergebnis nicht', () async {
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang(), const []);

      final vorschau = aufbau.cubit.erstelleVorschau();
      await aufbau.cubit.drucke();
      await vorschau;

      final stand = aufbau.cubit.state;
      expect(stand.phase, VollmachtPhase.abgeschlossen);
      expect(stand.abschluss?.vermerkt, isTrue);
      expect(stand.vorschau?.status, VollmachtVorschauStatus.erstellt);
      expect(stand.vorschauLaedt, isFalse);
    });

    test(
      'ohne ableitbare Art ist sie erst fällig, wenn der Anwalt wählt',
      () async {
        final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
        await aufbau.cubit.starte(
          vorgang(rechtsgebiet: 'Familienrecht', abteilung: 'C02'),
          const [],
        );
        expect(aufbau.cubit.state.vorschauFaellig, isFalse);

        aufbau.cubit.waehleArt(VollmachtArt.unfallsachen);

        expect(aufbau.cubit.state.vorschauFaellig, isTrue);
      },
    );

    test('fehlt die Vorlage, wird keine Vorschau bestellt', () async {
      dienst.vorlagen = VollmachtRepositoryDouble.standMit({
        VollmachtArt.unfallsachen,
      });
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang(), const []);
      expect(aufbau.cubit.state.vorschauFaellig, isFalse);

      await aufbau.cubit.erstelleVorschau();

      expect(dienst.vorschauAuftraege, isEmpty);
    });
  });

  group('Drucker', () {
    test('ohne eingerichteten Drucker ist „Drucken" gesperrt, „In Word öffnen" nicht', () async {
      dienst.drucker = const VollmachtDrucker(
        zustand: VollmachtDruckerZustand.keinDrucker,
      );
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);

      await aufbau.cubit.starte(vorgang(), const []);

      expect(aufbau.cubit.state.druckbereit, isFalse);
      expect(aufbau.cubit.state.bereit, isTrue);
    });

    test('ein offline gemeldeter Drucker sperrt nichts', () async {
      dienst.drucker = const VollmachtDrucker(
        name: 'Kanzleidrucker',
        zustand: VollmachtDruckerZustand.offline,
        hinweis: 'offline',
      );
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);

      await aufbau.cubit.starte(vorgang(), const []);

      expect(aufbau.cubit.state.druckbereit, isTrue);
    });
  });

  group('Ergebnis nach dem Druck', () {
    test(
      'bleibt mit Drucker und Vermerk stehen, statt den Dialog zu schließen',
      () async {
        dienst.druckErgebnis = const VollmachtErgebnis(
          status: VollmachtErgebnisStatus.gedruckt,
          drucker: 'Flurdrucker',
        );
        final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
        await aufbau.cubit.starte(vorgang(), const []);

        await aufbau.cubit.drucke();

        final stand = aufbau.cubit.state;
        expect(stand.phase, VollmachtPhase.abgeschlossen);
        expect(stand.abschluss?.weg, VollmachtAbschlussWeg.gedruckt);
        expect(stand.abschluss?.drucker, 'Flurdrucker');
        expect(stand.abschluss?.vermerkt, isTrue);
      },
    );

    test('nennt Word keinen Drucker, steht der Standarddrucker da', () async {
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang(), const []);

      await aufbau.cubit.drucke();

      expect(aufbau.cubit.state.abschluss?.drucker, 'Kanzleidrucker');
    });

    test('„Vermerk zurücknehmen" führt mit den Eingaben zurück', () async {
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang(), const []);
      aufbau.cubit.aendereKopfdaten(
        aufbau.cubit.state.kopfdaten.copyWith(telefon: '0170 0000000'),
      );
      await aufbau.cubit.drucke();

      await aufbau.cubit.nimmVermerkZurueck();

      final stand = aufbau.cubit.state;
      expect(vorgaenge.vermerke, [(referenz, true), (referenz, false)]);
      expect(stand.phase, VollmachtPhase.eingabe);
      expect(stand.abschluss, isNull);
      expect(stand.hinweis, contains('zurückgenommen'));
      expect(stand.kopfdaten.telefon, '0170 0000000');
    });

    test(
      '„Erneut drucken" nimmt den Vermerk zurück und setzt ihn neu',
      () async {
        final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
        await aufbau.cubit.starte(vorgang(), const []);
        await aufbau.cubit.drucke();

        await aufbau.cubit.druckeErneut();

        expect(dienst.gedruckt, hasLength(2));
        expect(vorgaenge.vermerke, [
          (referenz, true),
          (referenz, false),
          (referenz, true),
        ]);
        expect(aufbau.cubit.state.phase, VollmachtPhase.abgeschlossen);
      },
    );

    /// „Kein Blatt gekommen?" heißt: Der erste Vermerk stimmt nicht. Scheitert
    /// auch der Neudruck, darf er nicht stehen bleiben — sonst zeigte die
    /// Kachel „gedruckt am …" für eine Vollmacht, die es nie gab.
    test('scheitert der Neudruck, bleibt kein alter Vermerk stehen', () async {
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang(), const []);
      await aufbau.cubit.drucke();
      dienst.druckErgebnis = const VollmachtErgebnis(
        status: VollmachtErgebnisStatus.druckFehlgeschlagen,
        pfad: r'C:\Arbeit\Vollmacht Strafsache.docx',
      );

      await aufbau.cubit.druckeErneut();

      expect(aufbau.cubit.state.phase, VollmachtPhase.inWordGeoeffnet);
      expect(vorgaenge.vermerke, [(referenz, true), (referenz, false)]);
      expect(
        aufbau.vorgaengeCubit.findeZuReferenz(referenz)?.vollmachtGedrucktAm,
        isNull,
      );
    });

    test(
      '„In Word öffnen" nach „Kein Blatt" nimmt den Vermerk ebenso zurück',
      () async {
        final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
        await aufbau.cubit.starte(vorgang(), const []);
        await aufbau.cubit.drucke();

        await aufbau.cubit.oeffneInWordErneut();

        expect(aufbau.cubit.state.phase, VollmachtPhase.inWordGeoeffnet);
        expect(vorgaenge.vermerke.last, (referenz, false));
      },
    );

    test(
      'ein gescheiterter Vermerk lässt sich aus dem Ergebnis nachholen',
      () async {
        vorgaenge.vermerkScheitert = true;
        final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
        await aufbau.cubit.starte(vorgang(), const []);
        await aufbau.cubit.drucke();
        expect(aufbau.cubit.state.abschluss?.vermerkt, isFalse);

        vorgaenge.vermerkScheitert = false;
        await aufbau.cubit.vermerkeErneut();

        expect(aufbau.cubit.state.abschluss?.vermerkt, isTrue);
        expect(vorgaenge.vermerke, [(referenz, true)]);
      },
    );

    test('„In Word öffnen" mit Bestätigung endet im selben Ergebnis', () async {
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang(), const []);
      await aufbau.cubit.oeffneInWord();

      await aufbau.cubit.vermerkeAlsGedruckt();

      final abschluss = aufbau.cubit.state.abschluss;
      expect(aufbau.cubit.state.phase, VollmachtPhase.abgeschlossen);
      expect(abschluss?.weg, VollmachtAbschlussWeg.inWord);
      expect(abschluss?.vermerkt, isTrue);
    });
  });
}
