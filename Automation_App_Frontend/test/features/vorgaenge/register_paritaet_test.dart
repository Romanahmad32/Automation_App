import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Registerspalten müssen auf dem Bildschirm dasselbe sagen wie in der
/// Word-/PDF-Datei (§6.2, #40).
///
/// Beide Seiten leiten ihre Zellen getrennt her — die Ansicht aus [Vorgang],
/// die Datei aus `RegisterZeilenBau` im Backend. Laufen sie auseinander, fällt
/// das niemandem auf, weil jede Seite für sich plausibel aussieht: Genau
/// deshalb steht die Erwartung hier als Test und nicht als Kommentar.
///
/// Die Gegenstücke im Backend sind `RegisterZeilenBauTests` — wer hier etwas
/// ändert, ändert es dort mit.
void main() {
  Vorgang vorgang({
    String? gegner = 'HUK',
    String? rechtsgebietRoh,
    String? versichererName,
    String? jahr,
    DateTime? angefragtAm,
  }) => Vorgang(
    referenz: '01/26 C03_HG-E 1427',
    angefragtAm: angefragtAm ?? DateTime(2026, 1, 5),
    mandantName: 'Mustermann',
    gegner: gegner,
    rechtsgebietRoh: rechtsgebietRoh,
    jahr: jahr,
    antwort: versichererName == null
        ? null
        : ZentralrufReplyData(versichererName: versichererName),
  );

  group('Spalte 3 — Parteien', () {
    test('der eingetragene Gegner hat Vortritt', () {
      expect(
        vorgang(versichererName: 'HUK-COBURG').parteienBezeichnung,
        'Mustermann ./. HUK',
      );
    });

    /// Ohne diesen Rückfall stünde in der Datei „Mustermann ./." mit hängendem
    /// Trenner, während der Bildschirm daneben den Versicherer zeigt.
    test('ohne Gegner tritt der Versicherer aus der Antwort ein', () {
      expect(
        vorgang(
          gegner: null,
          versichererName: 'HUK-COBURG',
        ).parteienBezeichnung,
        'Mustermann ./. HUK-COBURG',
      );
    });

    /// Ein leer eingetragener Gegner zählt wie gar keiner — sonst hinge die
    /// Antwort daran, ob das Feld einmal angetippt wurde.
    test('ein leerer Gegner zählt wie keiner', () {
      expect(
        vorgang(
          gegner: '   ',
          versichererName: 'HUK-COBURG',
        ).parteienBezeichnung,
        'Mustermann ./. HUK-COBURG',
      );
    });

    test('ohne beides bleibt die Zelle leer statt „./.“', () {
      expect(vorgang(gegner: null).parteienBezeichnung, 'Mustermann ./.');
    });
  });

  group('Spalte 4 — Rechtsgebiet', () {
    /// Ein nie erfasstes Sachgebiet steht in einem Sachgebiete-Register als
    /// Strich und nicht als „Verkehrsrecht": Die tolerante Abbildung in
    /// [Rechtsgebiet.fromValue] ist fürs Bearbeiten gedacht, als Registerzeile
    /// wäre sie eine Behauptung.
    test('ein leerer gespeicherter Wert wird zum Strich', () {
      expect(
        vorgang(rechtsgebietRoh: '').rechtsgebietAnzeige,
        Rechtsgebiet.unbekannt,
      );
    });

    test('ein bekannter Wert bekommt seinen Anzeigenamen', () {
      expect(
        vorgang(rechtsgebietRoh: 'verkehrsstrafrecht').rechtsgebietAnzeige,
        'Verkehrsstrafrecht',
      );
    });

    /// Wie im Backend: gross geschrieben statt auf ein bekanntes Gebiet
    /// gebogen. „Mietrecht" ist die ehrlichere Zelle als „Verkehrsrecht".
    test('ein unbekannter Wert wird gross geschrieben, nicht ersetzt', () {
      expect(
        vorgang(rechtsgebietRoh: 'mietrecht').rechtsgebietAnzeige,
        'Mietrecht',
      );
    });

    /// Ohne übergebenen Rohwert zählt das gesetzte Rechtsgebiet — ein im Code
    /// gebauter Vorgang ist nicht „nie erfasst".
    test('ohne Rohwert zählt das gesetzte Rechtsgebiet', () {
      expect(vorgang().rechtsgebietAnzeige, 'Verkehrsrecht');
    });
  });

  /// Der Jahrgang ist die Überschrift, unter der eine Zeile im Register steht.
  /// Weichen die Seiten ab, sortiert der Bildschirm einen Vorgang unter „2026"
  /// und die Datei denselben unter „2024" — das Gegenstück ist
  /// `RegisterZeilenBauTests.Jahrgang_NimmtNurZiffern`.
  group('Jahrgang', () {
    test('zweistellig wird zur vierstelligen Überschrift', () {
      expect(RegisterFilter.jahrgang(vorgang(jahr: '26')), '2026');
    });

    test('vierstellig bleibt stehen', () {
      expect(RegisterFilter.jahrgang(vorgang(jahr: '2026')), '2026');
    });

    /// `int.tryParse` nahm das Vorzeichen an und machte aus „-1" den Jahrgang
    /// „20-1", während das Backend auf das Datum zurückfiel.
    test('was keine reine Ziffernfolge ist, fällt auf das Datum zurück', () {
      for (final jahr in ['-1', '+1', '٢٦', '2o']) {
        expect(
          RegisterFilter.jahrgang(
            vorgang(jahr: jahr, angefragtAm: DateTime(2024, 3, 7)),
          ),
          '2024',
          reason: '„$jahr" ist keine Jahreszahl',
        );
      }
    });
  });
}
