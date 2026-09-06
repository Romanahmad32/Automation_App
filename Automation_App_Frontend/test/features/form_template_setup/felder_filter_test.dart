import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/felder_filter.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Auswahl über der Feldertabelle (#104). Geprüft wird die Rechnung, nicht
/// der Knopf: Welche Zeilen bleiben stehen, welche Zahl steht daneben, und
/// womit geht die Karte auf.
///
/// Beide Regeln kommen von woanders und werden hier nur zusammengeführt —
/// „offen" aus `VorlagenStand`, „zu prüfen" aus `FeldDatenquelleErkennung`.
/// Genau deshalb steht hier auch die Gegenprobe, dass der Filter dasselbe
/// zählt, was die Zeile darunter anzeigt.
void main() {
  /// Ein Feld, wie es auf der offenen Detailseite steht: In `label` liegt der
  /// Control-Schlüssel, nicht der Name (siehe `FALLSTRICKE.md`).
  FieldData feld(
    int index, {
    FeldDatenquelle datenquelle = FeldDatenquelle.keine,
  }) => FieldData(
    order: index,
    label: 'field_$index',
    required: false,
    inputType: InputType.text,
    datenquelle: datenquelle,
  );

  /// Der Namensauflöser der Detailseite, hier aus einer Liste.
  String? Function(String) aufloeser(List<String> namen) =>
      (schluessel) => namen[int.parse(schluessel.split('_').last)];

  /// Eine Vorlage mit einer Word-Datei, die `{{Kennzeichen}}` und
  /// `{{Fahrzeug}}` kennt.
  VorlagenStand standMit(List<String> namen) => VorlagenStand.bestimme(
    hatDateiOhne: true,
    hatDateiMit: false,
    platzhalterOhne: const ['Kennzeichen', 'Fahrzeug'],
    platzhalterMit: null,
    feldnamen: namen,
  );

  group('sichtbare Zeilen', () {
    final namen = ['Kennzeichen', 'Zeichen', 'VersicherungPlzOrt'];
    final fields = [feld(0), feld(1), feld(2)];
    final stand = standMit(namen);

    test('„Alle" lässt jede Zeile stehen', () {
      expect(
        FelderFilter.alle.sichtbareIndizes(
          fields: fields,
          feldname: aufloeser(namen),
          stand: stand,
        ),
        [0, 1, 2],
      );
    });

    test('„Nur offene" zeigt genau die Felder ohne Vorkommen', () {
      // „Kennzeichen" steht in der Datei, die beiden anderen nirgends.
      expect(stand.felderOhneVorkommen, ['Zeichen', 'VersicherungPlzOrt']);
      expect(
        FelderFilter.nurOffene.sichtbareIndizes(
          fields: fields,
          feldname: aufloeser(namen),
          stand: stand,
        ),
        [1, 2],
      );
    });

    test('„Zu prüfen" zeigt genau die mehrdeutigen Namen', () {
      // `{{VersicherungPlzOrt}}` meint PLZ **und** Ort und bleibt deshalb
      // ungebunden — derselbe Befund, den `FeldNameHinweis` erklärt.
      expect(
        FelderFilter.zuPruefen.sichtbareIndizes(
          fields: fields,
          feldname: aufloeser(namen),
          stand: stand,
        ),
        [2],
      );
    });

    test('eine gesetzte Datenquelle nimmt die Zeile aus „Zu prüfen"', () {
      // Sie gewinnt über die Erkennung; der Hinweis unter dem Feld schweigt
      // dann auch. Stünde die Zeile trotzdem im Filter, führte er auf eine
      // Zeile, an der nichts zu sehen ist.
      final entschieden = [
        feld(0),
        feld(1),
        feld(2, datenquelle: FeldDatenquelle.versichererPlz),
      ];
      expect(
        FelderFilter.zuPruefen.sichtbareIndizes(
          fields: entschieden,
          feldname: aufloeser(namen),
          stand: stand,
        ),
        isEmpty,
      );
    });

    test('ohne Stand wird nicht gefiltert', () {
      // Vor dem Lesen der Platzhalter ist über kein Feld etwas bekannt —
      // dann alles zeigen statt willkürlich Zeilen wegzulassen.
      for (final filter in FelderFilter.values) {
        expect(
          filter.sichtbareIndizes(
            fields: fields,
            feldname: aufloeser(namen),
            stand: null,
          ),
          [0, 1, 2],
          reason: filter.name,
        );
      }
    });
  });

  group('Zahl auf dem Knopf', () {
    final namen = ['Kennzeichen', 'Zeichen', 'VersicherungPlzOrt'];
    final fields = [feld(0), feld(1), feld(2)];
    final stand = standMit(namen);

    int? zahl(FelderFilter filter) =>
        filter.anzahl(fields: fields, feldname: aufloeser(namen), stand: stand);

    test('„Alle" trägt keine — sie stünde schon im Kartentitel', () {
      expect(zahl(FelderFilter.alle), isNull);
      expect(FelderFilter.alle.beschriftungMitZahl(null), 'Alle');
    });

    test('„Nur offene" zählt die Platzhalter ohne Feld mit', () {
      // Zwei Felder ohne Vorkommen und ein Platzhalter ohne Feld
      // („Fahrzeug"). Stünde hier nur die Zeilenzahl, sagte der Knopf „2",
      // während über der Karte drei offene Punkte gemeldet sind.
      expect(stand.platzhalterOhneFeld, ['Fahrzeug']);
      expect(zahl(FelderFilter.nurOffene), 3);
      expect(FelderFilter.nurOffene.beschriftungMitZahl(3), 'Nur offene (3)');
    });

    test('„Zu prüfen" zählt seine Zeilen', () {
      expect(zahl(FelderFilter.zuPruefen), 1);
    });
  });

  group('Startwert', () {
    test('eine unvollständige Vorlage geht auf „Nur offene" auf', () {
      // Sie wird geöffnet, weil ihr etwas fehlt — dann soll das Fehlende
      // dastehen und nicht in achtzehn Zeilen versteckt sein.
      final stand = standMit(['Kennzeichen']);
      expect(stand.istVollstaendig, isFalse);
      expect(FelderFilter.start(stand), FelderFilter.nurOffene);
    });

    test('eine vollständige Vorlage geht auf „Alle" auf', () {
      final stand = VorlagenStand.bestimme(
        hatDateiOhne: true,
        hatDateiMit: false,
        platzhalterOhne: const ['Kennzeichen'],
        platzhalterMit: null,
        feldnamen: const ['Kennzeichen'],
      );
      expect(stand.istVollstaendig, isTrue);
      expect(FelderFilter.start(stand), FelderFilter.alle);
    });

    test('ohne Stand bleibt es bei „Alle"', () {
      expect(FelderFilter.start(null), FelderFilter.alle);
    });
  });
}
