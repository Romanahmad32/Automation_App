import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/domain/services/datenquelle_vorschlaege.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// #17: Was sich aus dem Bestand nicht *eindeutig* ergibt, wird nicht geraten,
/// sondern am Feld zur Wahl gestellt. Hier steht, welche Werte dabei
/// herauskommen — und welche nicht zweimal.
void main() {
  Mandant mandant({List<String> kennzeichen = const []}) => Mandant(
    id: 7,
    vorname: 'Erika',
    nachname: 'Mustermann',
    kennzeichen: kennzeichen,
    erstelltAm: DateTime(2026, 1, 1),
  );

  Vorgang vorgang({String? geschaedigtenKennzeichen}) => Vorgang.ausAnfrage(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 4, 8),
    mandantId: 7,
    mandantName: 'Erika Mustermann',
    geschaedigtenKennzeichen: geschaedigtenKennzeichen,
  );

  /// Derselbe Vorgang mit übernommener Zentralruf-Antwort — sein
  /// Gegnerkennzeichen `GG-XY 123` steckt in der Referenz.
  Vorgang mitAntwort(ZentralrufReplyData antwort) =>
      vorgang().copyWith(antwort: antwort);

  FieldData feld(
    String label, {
    FeldDatenquelle quelle = FeldDatenquelle.keine,
    InputType inputType = InputType.text,
  }) => FieldData(
    order: 0,
    label: label,
    required: false,
    inputType: inputType,
    datenquelle: quelle,
  );

  group('fuer (kennzeichenMandant)', () {
    test('nennt den Vorgang vor dem Register', () {
      final vorschlaege = DatenquelleVorschlaege.fuer(
        FeldDatenquelle.kennzeichenMandant,
        vorgang: vorgang(geschaedigtenKennzeichen: 'HG-E 1427'),
        mandant: mandant(kennzeichen: ['F-AB 12', 'WI-CD 345']),
      );

      expect(vorschlaege, [
        const FeldVorschlag('HG-E 1427', PrefillQuelle.vorgang),
        const FeldVorschlag('F-AB 12', PrefillQuelle.mandant),
        const FeldVorschlag('WI-CD 345', PrefillQuelle.mandant),
      ]);
    });

    /// Dasselbe Fahrzeug zweimal in der Liste sieht nach zwei Fahrzeugen aus —
    /// und der Anwalt sucht den Unterschied, den es nicht gibt.
    test('erkennt dasselbe Fahrzeug in anderer Schreibweise wieder', () {
      final vorschlaege = DatenquelleVorschlaege.fuer(
        FeldDatenquelle.kennzeichenMandant,
        vorgang: vorgang(geschaedigtenKennzeichen: 'HG-E 1427'),
        mandant: mandant(kennzeichen: ['HGE1427', 'hg e 1427', 'F-AB 12']),
      );

      expect(vorschlaege, [
        const FeldVorschlag('HG-E 1427', PrefillQuelle.vorgang),
        const FeldVorschlag('F-AB 12', PrefillQuelle.mandant),
      ]);
    });

    test('bringt jeden Wert in die Konvention HG-E 1427', () {
      final vorschlaege = DatenquelleVorschlaege.fuer(
        FeldDatenquelle.kennzeichenMandant,
        mandant: mandant(kennzeichen: ['gg-xy123', 'HG-E1427H']),
      );

      expect(vorschlaege.map((v) => v.wert), ['GG-XY 123', 'HG-E 1427H']);
    });

    test('lässt Leeres weg, statt eine leere Zeile anzubieten', () {
      final vorschlaege = DatenquelleVorschlaege.fuer(
        FeldDatenquelle.kennzeichenMandant,
        vorgang: vorgang(geschaedigtenKennzeichen: '   '),
        mandant: mandant(kennzeichen: ['', 'F-AB 12']),
      );

      expect(vorschlaege, [
        const FeldVorschlag('F-AB 12', PrefillQuelle.mandant),
      ]);
    });

    test('ohne Vorgang und ohne Register bleibt die Liste leer', () {
      expect(
        DatenquelleVorschlaege.fuer(FeldDatenquelle.kennzeichenMandant),
        isEmpty,
      );
    });
  });

  /// Der Vorgang kennt das Gegnerkennzeichen aus der Referenz, die Antwort aus
  /// dem Bestand des Zentralrufs — die beiden können auseinanderlaufen
  /// (Vertipper beim Start, anderer Wagen desselben Halters). Vorbelegt wird
  /// der erste; welcher ins Anspruchsschreiben gehört, entscheidet der Anwalt.
  group('fuer (kennzeichenGegner)', () {
    test('nennt den Vorgang vor der Zentralruf-Antwort', () {
      final vorschlaege = DatenquelleVorschlaege.fuer(
        FeldDatenquelle.kennzeichenGegner,
        vorgang: mitAntwort(const ZentralrufReplyData(kennzeichen: 'F-AB 12')),
      );

      expect(vorschlaege, [
        const FeldVorschlag('GG-XY 123', PrefillQuelle.vorgang),
        const FeldVorschlag('F-AB 12', PrefillQuelle.antwort),
      ]);
    });

    test('nennt denselben Wagen nur einmal', () {
      final vorschlaege = DatenquelleVorschlaege.fuer(
        FeldDatenquelle.kennzeichenGegner,
        vorgang: mitAntwort(const ZentralrufReplyData(kennzeichen: 'ggxy123')),
      );

      expect(vorschlaege, [
        const FeldVorschlag('GG-XY 123', PrefillQuelle.vorgang),
      ]);
    });

    test('ohne Antwort bleibt der Wert des Vorgangs allein stehen', () {
      expect(
        DatenquelleVorschlaege.fuer(
          FeldDatenquelle.kennzeichenGegner,
          vorgang: vorgang(),
        ),
        [const FeldVorschlag('GG-XY 123', PrefillQuelle.vorgang)],
      );
    });

    test('ohne Vorgang bleibt die Liste leer', () {
      expect(
        DatenquelleVorschlaege.fuer(FeldDatenquelle.kennzeichenGegner),
        isEmpty,
      );
    });
  });

  /// Der Ausbauweg steht in der Klasse; heute liefern nur die beiden
  /// Kennzeichen-Quellen Kandidaten. Dieser Test hält fest, dass die anderen
  /// **still** leer bleiben statt irgendetwas anzubieten.
  test('andere Quellen bieten (noch) nichts an', () {
    const mitKandidaten = [
      FeldDatenquelle.kennzeichenMandant,
      FeldDatenquelle.kennzeichenGegner,
    ];
    for (final quelle in FeldDatenquelle.values) {
      if (mitKandidaten.contains(quelle)) continue;
      expect(
        DatenquelleVorschlaege.fuer(
          quelle,
          vorgang: vorgang(geschaedigtenKennzeichen: 'HG-E 1427'),
          mandant: mandant(kennzeichen: ['F-AB 12']),
        ),
        isEmpty,
        reason: quelle.value,
      );
    }
  });

  group('fuerFelder', () {
    test('nimmt die am Feld gesetzte Quelle', () {
      final vorschlaege = DatenquelleVorschlaege.fuerFelder([
        feld(
          'Fahrzeug',
          quelle: FeldDatenquelle.kennzeichenMandant,
          inputType: InputType.kennzeichen,
        ),
      ], mandant: mandant(kennzeichen: ['F-AB 12', 'WI-CD 345']));

      expect(vorschlaege.keys, ['Fahrzeug']);
      expect(vorschlaege['Fahrzeug']!.map((v) => v.wert), [
        'F-AB 12',
        'WI-CD 345',
      ]);
    });

    /// Bestandsvorlagen tragen keine Quelle — für sie löst dieselbe Erkennung
    /// den Namen auf, die auch die Vorbelegung nimmt.
    test('löst einen ungebundenen Feldnamen über die Erkennung auf', () {
      final vorschlaege = DatenquelleVorschlaege.fuerFelder([
        feld('Kennzeichen des Geschädigten'),
      ], mandant: mandant(kennzeichen: ['F-AB 12', 'WI-CD 345']));

      expect(vorschlaege.keys, ['Kennzeichen des Geschädigten']);
    });

    test('trägt nur Felder ein, die auch Werte haben', () {
      final vorschlaege = DatenquelleVorschlaege.fuerFelder(
        [
          feld('Kennzeichen Mandant'),
          // Ein Feld ohne erkennbare Quelle: keine Auswahlhilfe, also gar
          // nicht in der Karte.
          feld('Notiz'),
        ],
        vorgang: vorgang(geschaedigtenKennzeichen: 'HG-E 1427'),
        mandant: mandant(),
      );

      expect(vorschlaege.keys, ['Kennzeichen Mandant']);
    });

    /// Auch das Gegnerfeld bekommt seine Auswahlhilfe über die Erkennung —
    /// der Wert steckt in der Referenz des Vorgangs.
    test('erkennt auch das Gegnerkennzeichen am Feldnamen', () {
      final vorschlaege = DatenquelleVorschlaege.fuerFelder([
        feld('Gegnerkennzeichen'),
      ], vorgang: vorgang());

      expect(vorschlaege['Gegnerkennzeichen']!.map((v) => v.wert), [
        'GG-XY 123',
      ]);
    });
  });
}
