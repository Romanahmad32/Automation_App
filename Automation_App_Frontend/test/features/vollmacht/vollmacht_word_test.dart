import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_abschluss.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vollmacht_doubles.dart';

/// „In Word öffnen" ist eine Nebenhandlung (§4.11, #174): Der Dialog bleibt in
/// der Eingabe, derselbe Knopf öffnet die Datei noch einmal, und was in Word
/// entstand, räumt der Dienst beim Schließen wieder ab (§8).
void main() {
  const referenz = '12/26 C05_GG-XY 1';
  const pfad = r'C:\Arbeit\Vollmacht Strafsache.docx';
  late VollmachtRepositoryDouble dienst;
  late VollmachtVorgaengeDouble vorgaenge;
  late List<String> geoeffnet;
  late bool oeffnenGelingt;

  final vorgang = Vorgang(
    referenz: referenz,
    angefragtAm: DateTime(2026, 9, 1),
    rechtsgebiet: 'Strafrecht',
    abteilung: 'C05',
  );

  setUp(() {
    dienst = VollmachtRepositoryDouble();
    vorgaenge = VollmachtVorgaengeDouble()..bestand[referenz] = vorgang;
    geoeffnet = [];
    oeffnenGelingt = true;
    DateiOeffner.oeffne = (pfad) async {
      geoeffnet.add(pfad);
      return oeffnenGelingt;
    };
  });

  tearDown(DateiOeffner.zuruecksetzen);

  Future<VollmachtCubit> gestartet() async {
    final cubit = (await baueVollmachtCubit(dienst, vorgaenge)).cubit;
    await cubit.starte(vorgang, const []);
    return cubit;
  }

  test('bleibt in der Eingabe und nennt die geöffnete Datei', () async {
    final cubit = await gestartet();
    final art = cubit.state.art;
    final kopfdaten = cubit.state.kopfdaten;

    await cubit.oeffneInWord();

    final stand = cubit.state;
    expect(stand.phase, VollmachtPhase.eingabe);
    expect(stand.bereit, isTrue, reason: 'Art, Felder und Knöpfe bleiben');
    expect(stand.art, art);
    expect(stand.kopfdaten, kopfdaten);
    expect(stand.wordFassung?.pfad, pfad);
    expect(stand.wordFassung?.dateiname, 'Vollmacht Strafsache.docx');
    expect(stand.wordFassung?.geoeffnet, isTrue);
    expect(geoeffnet, [pfad]);
  });

  test(
    'unverändert öffnet derselbe Knopf dieselbe Datei, ohne neu auszufüllen',
    () async {
      final cubit = await gestartet();

      await cubit.oeffneInWord();
      await cubit.oeffneInWord();

      expect(dienst.ausgefuellt, hasLength(1));
      expect(geoeffnet, [pfad, pfad]);
      expect(cubit.state.phase, VollmachtPhase.eingabe);
    },
  );

  test('nach geänderten Feldern oder anderer Art füllt er neu aus', () async {
    final cubit = await gestartet();
    await cubit.oeffneInWord();

    cubit.aendereKopfdaten(cubit.state.kopfdaten.copyWith(ort: 'Musterstadt'));
    await cubit.oeffneInWord();
    cubit.waehleArt(VollmachtArt.unfallsachen);
    await cubit.oeffneInWord();

    expect(dienst.ausgefuellt, hasLength(3));
    expect(dienst.ausgefuellt[1].kopfdaten.ort, 'Musterstadt');
    expect(dienst.ausgefuellt[2].art, VollmachtArt.unfallsachen);
    expect(cubit.state.wordFassung?.auftrag, cubit.state.auftrag);
  });

  test('ist die Datei weg, füllt er neu aus', () async {
    final cubit = await gestartet();
    await cubit.oeffneInWord();
    oeffnenGelingt = false;

    await cubit.oeffneInWord();

    expect(dienst.ausgefuellt, hasLength(2));
    expect(
      cubit.state.wordFassung?.geoeffnet,
      isFalse,
      reason: 'Die Leiste sagt, dass Word sich nicht anstoßen ließ.',
    );
  });

  test('hält Word die alte Fassung, kommt die Meldung des Dienstes und die Leiste bleibt', () async {
    final cubit = await gestartet();
    await cubit.oeffneInWord();
    final erste = cubit.state.wordFassung;
    const gesperrt =
        'Die Datei „Vollmacht Strafsache.docx“ ist noch in Word geöffnet.';
    dienst.ausfuellErgebnis = const VollmachtErgebnis(
      status: VollmachtErgebnisStatus.fehler,
      meldung: gesperrt,
    );

    cubit.aendereKopfdaten(cubit.state.kopfdaten.copyWith(ort: 'Musterstadt'));
    await cubit.oeffneInWord();

    expect(cubit.state.phase, VollmachtPhase.eingabe);
    expect(cubit.state.fehler, gesperrt);
    expect(cubit.state.wordFassung, erste);
  });

  test('„Als gedruckt vermerken" aus der Eingabe führt ins Ergebnis', () async {
    final cubit = await gestartet();
    await cubit.oeffneInWord();

    await cubit.vermerkeAlsGedruckt();

    expect(cubit.state.phase, VollmachtPhase.abgeschlossen);
    expect(cubit.state.abschluss?.weg, VollmachtAbschlussWeg.inWord);
    expect(vorgaenge.vermerke, [(referenz, true)]);
  });

  test('ohne Word-Fassung gibt es nichts zu vermerken', () async {
    final cubit = await gestartet();

    await cubit.vermerkeAlsGedruckt();

    expect(vorgaenge.vermerke, isEmpty);
    expect(cubit.state.phase, VollmachtPhase.eingabe);
  });

  test('aus dem Ergebnis öffnet „In Word öffnen" dieselbe Datei, ohne Vermerk, in der Eingabe', () async {
    final cubit = await gestartet();
    await cubit.oeffneInWord();
    await cubit.vermerkeAlsGedruckt();

    await cubit.oeffneInWordErneut();

    expect(vorgaenge.vermerke, [(referenz, true), (referenz, false)]);
    expect(dienst.ausgefuellt, hasLength(1));
    expect(geoeffnet, [pfad, pfad]);
    expect(cubit.state.phase, VollmachtPhase.eingabe);
    expect(cubit.state.abschluss, isNull);
  });

  test('ein gelungener Druck ersetzt die Word-Fassung', () async {
    final cubit = await gestartet();
    await cubit.oeffneInWord();

    await cubit.drucke();

    expect(cubit.state.phase, VollmachtPhase.abgeschlossen);
    expect(cubit.state.wordFassung, isNull);
    expect(cubit.state.wordFassungEntstanden, isTrue);
  });

  group('Schließen', () {
    test('räumt auf, wenn eine Word-Fassung entstand', () async {
      final cubit = await gestartet();
      await cubit.oeffneInWord();

      await cubit.close();

      expect(dienst.aufgeraeumt, [referenz]);
    });

    test(
      'räumt auch nach einem Druck auf, der eine Word-Fassung ersetzte',
      () async {
        final cubit = await gestartet();
        await cubit.oeffneInWord();
        await cubit.drucke();

        await cubit.close();

        expect(dienst.aufgeraeumt, [referenz]);
      },
    );

    test('ohne Word-Fassung lässt es den Dienst in Ruhe', () async {
      final cubit = await gestartet();
      await cubit.drucke();

      await cubit.close();

      expect(dienst.aufgeraeumt, isEmpty);
    });
  });
}
