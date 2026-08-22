import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:flutter_test/flutter_test.dart';

VorgangStartenDaten _daten({
  String vorname = '',
  String nachname = '',
  String strasse = '',
  String mandantKennzeichen = '',
}) {
  return VorgangStartenDaten(
    auftragsnummer: 1,
    auftragsjahr: 26,
    abteilung: 'C03',
    rechtsgebiet: Rechtsgebiet.verkehrsrecht,
    referenz: '1/26 C03',
    vorname: vorname,
    nachname: nachname,
    strasseHausnummer: strasse,
    mandantKennzeichen: mandantKennzeichen,
  );
}

Mandant _mandant() => Mandant(
  id: 7,
  vorname: 'Max',
  nachname: 'Müller',
  strasseHausnummer: 'Hauptstr. 1',
  kennzeichen: const ['HG-E 1427'],
  erstelltAm: DateTime(2026),
);

void main() {
  group('mandantAenderungsart', () {
    test('ohne Auswahl und ohne Namen: keine', () {
      expect(mandantAenderungsart(_daten(), null), MandantAenderungsart.keine);
    });

    test('ohne Auswahl, aber mit Namen: neu', () {
      expect(
        mandantAenderungsart(_daten(vorname: 'Anna', nachname: 'Klein'), null),
        MandantAenderungsart.neu,
      );
    });

    test('mit gewähltem, unverändertem Mandanten: keine', () {
      final daten = _daten(
        vorname: 'Max',
        nachname: 'Müller',
        strasse: 'Hauptstr. 1',
        mandantKennzeichen: 'HG-E 1427',
      );
      expect(
        mandantAenderungsart(daten, _mandant()),
        MandantAenderungsart.keine,
      );
    });

    test('mit geänderter Adresse: aktualisierung', () {
      final daten = _daten(
        vorname: 'Max',
        nachname: 'Müller',
        strasse: 'Hauptstr. 2',
      );
      expect(
        mandantAenderungsart(daten, _mandant()),
        MandantAenderungsart.aktualisierung,
      );
    });
  });

  test('mandantDiff zeigt nur geänderte Felder als alt → neu', () {
    final daten = _daten(
      vorname: 'Max',
      nachname: 'Müller',
      strasse: 'Hauptstr. 2',
      mandantKennzeichen: 'F-AB 12',
    );
    final diffs = mandantDiff(daten, _mandant());

    final labels = diffs.map((d) => d.label).toList();
    expect(labels, contains('Straße und Hausnummer'));
    expect(labels, contains('Kfz-Kennzeichen (neu)'));
    expect(labels, isNot(contains('Name')));

    final strasse = diffs.firstWhere((d) => d.label == 'Straße und Hausnummer');
    expect(strasse.alt, 'Hauptstr. 1');
    expect(strasse.neu, 'Hauptstr. 2');
  });

  test('mandantNeuFelder listet nur ausgefüllte Felder', () {
    final felder = mandantNeuFelder(
      _daten(vorname: 'Anna', nachname: 'Klein', strasse: 'Weg 3'),
    );
    final labels = felder.map((f) => f.label).toList();
    expect(labels, ['Name', 'Straße und Hausnummer']);
    expect(felder.first.neu, 'Anna Klein');
  });
}
