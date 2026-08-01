import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/word_automation/presentation/utils/formular_extraktion.dart';
import 'package:flutter_test/flutter_test.dart';

FieldData feld(String label, InputType type) =>
    FieldData(order: 0, label: label, required: false, inputType: type);

void main() {
  group('ursachendatumAusFormular', () {
    test('bevorzugt ein Unfall-/Datumsfeld', () {
      final fields = [
        feld('Geburtsdatum Mandant', InputType.date),
        feld('Unfalldatum', InputType.date),
      ];
      final data = {
        'Geburtsdatum Mandant': '01.01.1980',
        'Unfalldatum': '12.05.2025',
      };
      expect(ursachendatumAusFormular(fields, data), '12.05.2025');
    });

    test('fällt auf das erste gefüllte Datumsfeld zurück', () {
      final fields = [feld('Stichtag', InputType.date)];
      expect(
        ursachendatumAusFormular(fields, {'Stichtag': '03.03.2024'}),
        '03.03.2024',
      );
    });

    test('liefert null ohne Datumsfeld', () {
      final fields = [feld('Name', InputType.text)];
      expect(ursachendatumAusFormular(fields, {'Name': 'Max'}), isNull);
    });
  });

  group('kennzeichenAusFormular', () {
    test('findet das Kennzeichen-Feld', () {
      expect(
        kennzeichenAusFormular({'Gegnerisches Kennzeichen': 'F-HI 412'}),
        'F-HI 412',
      );
    });
  });

  group('baueDateiname', () {
    test(
        'kombiniert Vorlagenname und Datum, entfernt .docx und _gen entfällt', () {
      final name = baueDateiname(
        r'C:\Vorlagen\Anspruchsschreiben.docx',
        '12.05.2025',
      );
      expect(name, 'Anspruchsschreiben 12.05.2025');
      expect(name, isNot(contains('_gen')));
    });

    test('ohne Datum nur der Vorlagenname', () {
      expect(
        baueDateiname('/pfad/VORLAGE HGN.docx', null),
        'VORLAGE HGN',
      );
    });
  });

  group('mandantDatenAusFormular', () {
    test('liest Name und Adresse aus passenden Labels', () {
      final daten = mandantDatenAusFormular({
        'Vorname Mandant': 'Max',
        'Nachname Mandant': 'Bein',
        'Straße Mandant': 'Hauptstr. 1',
        'PLZ': '61348',
        'Ort': 'Bad Homburg',
        'Name Versicherung': 'Allianz',
      });
      expect(daten.vorname, 'Max');
      expect(daten.nachname, 'Bein');
      expect(daten.strasseHausnummer, 'Hauptstr. 1');
      expect(daten.ort, 'Bad Homburg');
    });
  });
}
