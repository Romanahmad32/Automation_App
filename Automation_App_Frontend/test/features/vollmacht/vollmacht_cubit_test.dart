import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_ergebnis.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vollmacht_doubles.dart';

/// Der Ablauf des Vollmacht-Dialogs (§4.11): vorbelegen, drucken, Rückfall
/// auf Word, Vermerk nur nach angenommenem Druck oder ausdrücklicher Bestätigung.
void main() {
  const referenz = '12/26 C05_GG-XY 1';
  late VollmachtRepositoryDouble dienst;
  late VollmachtVorgaengeDouble vorgaenge;
  late List<String> geoeffnet;

  Vorgang vorgang({int? mandantId = 7}) => Vorgang(
    referenz: referenz,
    angefragtAm: DateTime(2026, 9, 1),
    rechtsgebiet: 'Strafrecht',
    abteilung: 'C05',
    mandantId: mandantId,
  );

  setUp(() {
    dienst = VollmachtRepositoryDouble();
    dienst.mandanten[7] = Mandant(
      id: 7,
      vorname: 'Max',
      nachname: 'Probe',
      strasseHausnummer: 'Probeweg 14',
      postleitzahl: '12345',
      ort: 'Musterstadt',
      erstelltAm: DateTime(2026),
    );
    vorgaenge = VollmachtVorgaengeDouble();
    geoeffnet = [];
    DateiOeffner.oeffne = (pfad) async {
      geoeffnet.add(pfad);
      return true;
    };
  });

  tearDown(DateiOeffner.zuruecksetzen);

  test('belegt Art und Kopfdaten aus Vorgang und Mandant vor', () async {
    vorgaenge.bestand[referenz] = vorgang();
    final aufbau = await baueVollmachtCubit(dienst, vorgaenge);

    await aufbau.cubit.starte(vorgang(), const []);

    final stand = aufbau.cubit.state;
    expect(stand.phase, VollmachtPhase.eingabe);
    expect(stand.art, VollmachtArt.strafsache);
    expect(stand.kopfdaten.wegen, 'Strafverfahren gegen Max Probe');
    expect(stand.mandantLage, VollmachtMandantLage.geladen);
    expect(stand.bereit, isTrue);
  });

  test(
    'ohne zugeordneten Mandanten bleiben die Felder leer und es heißt warum',
    () async {
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);

      await aufbau.cubit.starte(vorgang(mandantId: null), const []);

      expect(aufbau.cubit.state.kopfdaten.name, '');
      expect(
        aufbau.cubit.state.mandantLage,
        VollmachtMandantLage.keinerZugeordnet,
      );
    },
  );

  test(
    'ein nicht ladbarer Mandant wird gemeldet, nicht verschwiegen',
    () async {
      dienst.mandantFehler = ServerFailure(message: 'Dienst weg.');
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);

      await aufbau.cubit.starte(vorgang(), const []);

      expect(
        aufbau.cubit.state.mandantLage,
        VollmachtMandantLage.nichtGefunden,
      );
      expect(aufbau.cubit.state.fehler, 'Dienst weg.');
    },
  );

  test('ein angenommener Druck wird am Vorgang vermerkt', () async {
    vorgaenge.bestand[referenz] = vorgang();
    final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
    await aufbau.cubit.starte(vorgang(), const []);

    await aufbau.cubit.drucke();

    expect(dienst.gedruckt.single.kopfdaten.nachname, 'Probe');
    expect(vorgaenge.vermerke, [(referenz, true)]);
    expect(aufbau.cubit.state.phase, VollmachtPhase.abgeschlossen);
    expect(
      aufbau.vorgaengeCubit.findeZuReferenz(referenz)!.vollmachtGedrucktAm,
      isNotNull,
    );
  });

  test(
    'ein gescheiterter Druck öffnet die Datei und vermerkt nichts',
    () async {
      vorgaenge.bestand[referenz] = vorgang();
      dienst.druckErgebnis = const VollmachtErgebnis(
        status: VollmachtErgebnisStatus.druckFehlgeschlagen,
        pfad: r'C:\Arbeit\Vollmacht Strafsache.docx',
        meldung: 'Word nicht erreichbar.',
      );
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang(), const []);

      await aufbau.cubit.drucke();

      expect(geoeffnet, [r'C:\Arbeit\Vollmacht Strafsache.docx']);
      expect(vorgaenge.vermerke, isEmpty);
      expect(aufbau.cubit.state.phase, VollmachtPhase.inWordGeoeffnet);
      expect(aufbau.cubit.state.fehler, 'Word nicht erreichbar.');
    },
  );

  test(
    '„In Word öffnen" vermerkt erst auf ausdrückliche Bestätigung',
    () async {
      vorgaenge.bestand[referenz] = vorgang();
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(vorgang(), const []);

      await aufbau.cubit.oeffneInWord();
      expect(dienst.gedruckt, isEmpty);
      expect(vorgaenge.vermerke, isEmpty);
      expect(aufbau.cubit.state.phase, VollmachtPhase.inWordGeoeffnet);

      await aufbau.cubit.vermerkeAlsGedruckt();
      expect(vorgaenge.vermerke, [(referenz, true)]);
      expect(aufbau.cubit.state.phase, VollmachtPhase.abgeschlossen);
    },
  );

  test('fehlt die Vorlage der Art, wird nichts gedruckt', () async {
    dienst.vorlagen = VollmachtRepositoryDouble.standMit({
      VollmachtArt.unfallsachen,
    });
    final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
    await aufbau.cubit.starte(vorgang(), const []);

    expect(aufbau.cubit.state.vorlageFehlt, isTrue);
    await aufbau.cubit.drucke();

    expect(dienst.gedruckt, isEmpty);
  });

  test(
    'ohne ableitbare Art wird nicht gedruckt, bis der Anwalt wählt',
    () async {
      final aufbau = await baueVollmachtCubit(dienst, vorgaenge);
      await aufbau.cubit.starte(
        Vorgang(
          referenz: referenz,
          angefragtAm: DateTime(2026, 9, 1),
          rechtsgebiet: 'Familienrecht',
          abteilung: 'C02',
        ),
        const [],
      );
      expect(aufbau.cubit.state.bereit, isFalse);

      aufbau.cubit.waehleArt(VollmachtArt.unfallsachen);

      expect(aufbau.cubit.state.bereit, isTrue);
      expect(
        aufbau.cubit.state.kopfdaten.wegen,
        'Schadensersatz nach Verkehrsunfall vom',
      );
    },
  );
}
