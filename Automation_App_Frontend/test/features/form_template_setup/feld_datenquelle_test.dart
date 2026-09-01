import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nagelt die **Persistenzschlüssel** fest — nicht die Anzeigenamen.
///
/// `FieldData` speichert eine Datenquelle als Zeichenkette (`datenquelle:
/// quelle.value`) und liest sie über `FeldDatenquelle.fromValue` zurück. Fällt
/// der Schlüssel weg, liefert `fromValue` still [FeldDatenquelle.keine]: kein
/// Fehler, keine Meldung, nur eine Vorlage, deren Feld ab sofort leer bleibt.
/// Auffallen würde das erst am fehlenden Wert im nächsten Schreiben.
///
/// Genau dieser Fall lag beim Umbenennen von „Aktenzeichen" auf „Zeichen"
/// (§4.2) offen: Der Anzeigename wechselte, der gespeicherte Wert durfte es
/// nicht. Statt den alten Wert kommentarlos stehen zu lassen — was wie ein
/// vergessenes Aufräumen aussieht und beim nächsten Mal genau so behandelt
/// würde — trägt die Quelle ihn als `frueher` und dieser Test hält beide Wege.
void main() {
  group('fromValue', () {
    test('liest den aktuellen Schlüssel', () {
      expect(FeldDatenquelle.fromValue('zeichen'), FeldDatenquelle.zeichen);
    });

    test('liest den früheren Schlüssel bestehender Vorlagen', () {
      // Die beiden angelegten Kanzleivorlagen tragen diesen Wert in der
      // Datenbank. Wer ihn aus der Quelle entfernt, nimmt ihnen die Zuordnung.
      expect(
        FeldDatenquelle.fromValue('aktenzeichen'),
        FeldDatenquelle.zeichen,
      );
    });

    test('unbekannte und fehlende Werte bleiben ungebunden', () {
      expect(FeldDatenquelle.fromValue('gibtesnicht'), FeldDatenquelle.keine);
      expect(FeldDatenquelle.fromValue(null), FeldDatenquelle.keine);
      expect(FeldDatenquelle.fromValue(''), FeldDatenquelle.keine);
    });

    test('jede Quelle findet über ihren eigenen value zurück', () {
      for (final quelle in FeldDatenquelle.values) {
        expect(
          FeldDatenquelle.fromValue(quelle.value),
          quelle,
          reason: 'Der Schlüssel „${quelle.value}" führt nicht zu $quelle.',
        );
      }
    });
  });

  test('kein Schlüssel kommt zweimal vor', () {
    // Ein doppelter Wert — auch zwischen `value` und einem `frueher` einer
    // anderen Quelle — macht `fromValue` von der Aufzählungsreihenfolge
    // abhängig: Dieselbe gespeicherte Vorlage läse sich dann je nach Position
    // im Enum anders.
    final gesehen = <String, FeldDatenquelle>{};
    for (final quelle in FeldDatenquelle.values) {
      for (final schluessel in [quelle.value, quelle.frueher]) {
        if (schluessel == null) continue;
        expect(
          gesehen.containsKey(schluessel),
          isFalse,
          reason:
              'Der Schlüssel „$schluessel" gehört schon zu '
              '${gesehen[schluessel]} und nun auch zu $quelle.',
        );
        gesehen[schluessel] = quelle;
      }
    }
  });
}
