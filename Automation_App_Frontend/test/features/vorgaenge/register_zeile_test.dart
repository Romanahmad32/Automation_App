import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Zeile der Registeransicht kommt seit Issue #109 aus dem Backend
/// (`RegisterZeileDto`). Frontend und Backend sind darüber nur über
/// Zeichenketten verbunden — ein Tippfehler im Feldnamen ist zur Laufzeit ein
/// stilles `null` und kein Übersetzungsfehler.
void main() {
  Map<String, dynamic> rohZeile() => {
    'jahr': '2019',
    'laufendeNummer': 10,
    'zeichen': '10/19-I C02',
    'parteien': 'Bernd Mustermann ./. Beate Mustermann',
    'sachbestand': 'Ehescheidung',
    'rechtsgebiet': 'Familienrecht',
    'abgeschlossen': true,
    'quelle': 'historie',
    'historieId': 42,
    'vorgangReferenz': null,
    'sicherheit': 'niedrig',
    'befunde': ['Nummer trägt den Zusatz „-I".'],
  };

  group('fromJson', () {
    test('liest jedes Feld der Antwort', () {
      final zeile = RegisterZeile.fromJson(rohZeile());

      expect(zeile.jahr, '2019');
      expect(zeile.laufendeNummer, 10);
      expect(zeile.zeichen, '10/19-I C02');
      expect(zeile.parteien, 'Bernd Mustermann ./. Beate Mustermann');
      expect(zeile.sachbestand, 'Ehescheidung');
      expect(zeile.rechtsgebiet, 'Familienrecht');
      expect(zeile.abgeschlossen, isTrue);
      expect(zeile.quelle, RegisterQuellen.historie);
      expect(zeile.historieId, 42);
      expect(zeile.vorgangReferenz, isNull);
      expect(zeile.sicherheit, RegisterSicherheiten.niedrig);
      expect(zeile.befunde, hasLength(1));
    });

    /// Ein fehlendes Feld darf die Ansicht nicht mit einer Ausnahme abwerfen —
    /// eine Zeile ohne Nummer ist der Normalfall (ein Vorgang bekommt sie erst
    /// beim Abschluss).
    test('verträgt fehlende Felder', () {
      final zeile = RegisterZeile.fromJson({'jahr': '2026'});

      expect(zeile.laufendeNummer, isNull);
      expect(zeile.zeichen, '');
      expect(zeile.befunde, isEmpty);
      expect(zeile.quelle, RegisterQuellen.vorgang);
      expect(zeile.istHistorie, isFalse);
    });

    test('liest die Liste aus dem Umschlag', () {
      final zeilen = RegisterZeile.listeAusJson({
        'zeilen': [rohZeile(), rohZeile()],
      });

      expect(zeilen, hasLength(2));
      expect(zeilen.first.historieId, 42);
    });

    test('ein Umschlag ohne Zeilen ist leer, kein Fehler', () {
      expect(RegisterZeile.listeAusJson(const {}), isEmpty);
    });
  });

  group('zuPruefen', () {
    test('eine sichere Zeile ohne Befund ist es nicht', () {
      final zeile = RegisterZeile.fromJson({
        ...rohZeile(),
        'sicherheit': 'hoch',
        'befunde': <String>[],
      });

      expect(zeile.zuPruefen, isFalse);
    });

    test('ein Befund genügt, auch bei hoher Sicherheit', () {
      final zeile = RegisterZeile.fromJson({
        ...rohZeile(),
        'sicherheit': 'hoch',
        'befunde': ['Ohne Abteilung.'],
      });

      expect(zeile.zuPruefen, isTrue);
    });

    /// Alles, was nicht ausdrücklich „hoch" sagt, gilt als prüfenswert —
    /// deshalb ist „ohne Angabe" der Rückfall und nicht „sicher".
    test('eine unbekannte Sicherheitsangabe zählt als prüfenswert', () {
      final zeile = RegisterZeile.fromJson({
        ...rohZeile(),
        'sicherheit': '',
        'befunde': <String>[],
      });

      expect(zeile.zuPruefen, isTrue);
      expect(zeile.sicherheitText, 'ohne Angabe');
    });

    test('die Sicherheitswörter sind die des Mandanten-Imports', () {
      expect(RegisterSicherheiten.bezeichnung('hoch'), 'sicher');
      expect(RegisterSicherheiten.bezeichnung('mittel'), 'unsicher');
      expect(RegisterSicherheiten.bezeichnung('niedrig'), 'sehr unsicher');
    });
  });

  /// Die Startseiten-Karte baut ihre Zeilen aus dem bereits geladenen
  /// Vorgangsbestand. Weicht diese Abbildung von `RegisterZeilenBau` im
  /// Backend ab, zeigt die Startseite etwas anderes als die Registerseite
  /// daneben.
  group('ausVorgang', () {
    Vorgang vorgang({String? jahr = '26', VorgangStatus? status}) => Vorgang(
      referenz: '215/26 C03_HG-E 1427',
      angefragtAm: DateTime(2026, 6, 20),
      status: status ?? VorgangStatus.versendet,
      laufendeNummer: 215,
      jahr: jahr,
      abteilung: 'C03',
      mandantName: 'Mustermann, Max',
      gegner: 'HUK-COBURG',
      unfallDatum: '20.06.2026',
    );

    test('übernimmt Zeichen, Sache und Sachbestand', () {
      final zeile = RegisterZeile.ausVorgang(vorgang());

      expect(zeile.jahr, '2026');
      expect(zeile.laufendeNummer, 215);
      expect(zeile.zeichen, '215/26 C03');
      expect(zeile.parteien, 'Mustermann, Max ./. HUK-COBURG');
      expect(zeile.sachbestand, 'Sachverhalt v. 20.06.2026');
      expect(zeile.vorgangReferenz, '215/26 C03_HG-E 1427');
      expect(zeile.istHistorie, isFalse);
    });

    test('nur ein versendeter Vorgang gilt als abgeschlossen', () {
      expect(RegisterZeile.ausVorgang(vorgang()).abgeschlossen, isTrue);
      expect(
        RegisterZeile.ausVorgang(
          vorgang(status: VorgangStatus.erstellt),
        ).abgeschlossen,
        isFalse,
      );
    });

    test('ohne Jahresfeld entscheidet das Datum', () {
      expect(RegisterZeile.ausVorgang(vorgang(jahr: null)).jahr, '2026');
    });
  });
}
