import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/verwendete_felder.dart';
import 'package:flutter_test/flutter_test.dart';

/// #82: Eine Vorlage hat zwei Word-Dateien, aber eine Feldliste. Diese Regel
/// sagt, welche Felder das Schreiben aus der *gerade gewählten* Datei
/// überhaupt einsetzt — die anderen klappt das Formular ein.
void main() {
  FieldData feld(String label) => FieldData(
    order: 0,
    label: label,
    required: false,
    inputType: InputType.text,
  );

  List<String> namen(List<FieldData> felder) => [
    for (final f in felder) f.label,
  ];

  group('wirdVerwendet', () {
    test('ein Name aus der aktiven Datei zählt', () {
      expect(
        VerwendeteFelder.wirdVerwendet('Versicherer', {'Versicherer'}),
        isTrue,
      );
    });

    test('ein Name nur aus der anderen Datei zählt nicht', () {
      expect(
        VerwendeteFelder.wirdVerwendet('Unfalldatum', {'Versicherer'}),
        isFalse,
      );
    });

    test('Groß-/Kleinschreibung und Leerzeichen spielen keine Rolle', () {
      // Die Ersetzung im Backend arbeitet mit `RegexOptions.IgnoreCase` —
      // wiche die Prüfung ab, verschwände ein Feld, das das Dokument füllt.
      expect(
        VerwendeteFelder.wirdVerwendet(' zahlungsfrist ', {'Zahlungsfrist'}),
        isTrue,
      );
    });

    test('ohne bekannte Platzhalter gilt jedes Feld als verwendet', () {
      // Der Rückfall zeigt hier in die andere Richtung als bei der Pflicht:
      // im Zweifel zeigen, nicht verbergen. Sonst verschluckte ein Lesefehler
      // (leere Menge) das ganze Formular.
      expect(VerwendeteFelder.wirdVerwendet('Versicherer', null), isTrue);
      expect(VerwendeteFelder.wirdVerwendet('Versicherer', const {}), isTrue);
    });
  });

  group('teile', () {
    test('trennt nach der aktiven Datei und hält die Reihenfolge', () {
      final aufteilung = VerwendeteFelder.teile(
        [
          feld('Vorname'),
          feld('Versicherer'),
          feld('Unfalldatum'),
          feld('Gegnerkennzeichen'),
        ],
        {'Gegnerkennzeichen', 'Versicherer'},
      );

      expect(namen(aufteilung.verwendet), ['Versicherer', 'Gegnerkennzeichen']);
      expect(namen(aufteilung.uebrig), ['Vorname', 'Unfalldatum']);
    });

    test('ohne bekannte Platzhalter bleibt nichts übrig', () {
      final aufteilung = VerwendeteFelder.teile([
        feld('Vorname'),
        feld('Versicherer'),
      ], const {});

      expect(namen(aufteilung.verwendet), ['Vorname', 'Versicherer']);
      expect(aufteilung.uebrig, isEmpty);
    });
  });
}
