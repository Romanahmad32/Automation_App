import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/domain/services/schreiben_dateiname.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Kanzlei-Konvention für den Dateinamen des Schreibens (§4.9, #32):
/// „Anspruchsschreiben an {Versicherung} {Nr} {Vorlagenname}".
void main() {
  Vorgang vorgang({
    String? versicherer,
    String? gegner,
    int? schreibenNummer,
  }) => Vorgang(
    referenz: '84/26 C03_HG-E 1427',
    angefragtAm: DateTime(2026, 6, 12),
    gegner: gegner,
    schreibenNummer: schreibenNummer,
    antwort: versicherer == null
        ? null
        : ZentralrufReplyData(versichererName: versicherer),
  );

  group('schreibenDateiname', () {
    test('folgt dem Schema aus Empfänger, Nummer und Vorlagenname', () {
      expect(
        schreibenDateiname(
          vorlagenname: 'Vorfahrtverletzung STOP 205',
          nummer: 1,
          versicherer: 'Allianz',
        ),
        'Anspruchsschreiben an Allianz 1 Vorfahrtverletzung STOP 205',
      );
    });

    test('das zweite Schreiben trägt die 2', () {
      expect(
        schreibenDateiname(
          vorlagenname: 'Vorfahrtverletzung STOP 205',
          nummer: 2,
          versicherer: 'Allianz',
        ),
        'Anspruchsschreiben an Allianz 2 Vorfahrtverletzung STOP 205',
      );
    });

    /// Ohne Versicherer fällt das „an" mit weg. Bliebe es stehen, entstünde
    /// „Anspruchsschreiben an  1 …" — ein doppeltes Leerzeichen, das aussieht
    /// wie ein Fehler und einer ist.
    test('ohne Versicherer kein doppeltes Leerzeichen', () {
      final name = schreibenDateiname(vorlagenname: 'HGN', nummer: 1);
      expect(name, 'Anspruchsschreiben 1 HGN');
      expect(name, isNot(contains('  ')));
    });

    test('leerer Versicherername zählt wie keiner', () {
      expect(
        schreibenDateiname(vorlagenname: 'HGN', nummer: 1, versicherer: '   '),
        'Anspruchsschreiben 1 HGN',
      );
    });

    /// Der Name der Vorlage ist nicht der Dateiname der Word-Datei — „VORLAGE"
    /// gehört nicht in ein fertiges Schreiben. Wer hier einen Pfad hereingibt,
    /// bekommt ihn ungefiltert zurück; gesäubert wird im Dienst
    /// (`OutputFileNaming`), damit es genau eine solche Stelle gibt.
    test('trimmt Vorlagenname und Versicherer', () {
      expect(
        schreibenDateiname(
          vorlagenname: '  Fahrspurwechsel  ',
          nummer: 3,
          versicherer: '  HUK  ',
        ),
        'Anspruchsschreiben an HUK 3 Fahrspurwechsel',
      );
    });
  });

  group('empfaengerFuerDateiname', () {
    test('nimmt die Versicherung aus der Zentralruf-Antwort', () {
      expect(
        empfaengerFuerDateiname(
          vorgang(versicherer: 'Allianz', gegner: 'Meier'),
        ),
        'Allianz',
      );
    });

    test('fällt auf den eingetragenen Gegner zurück', () {
      expect(
        empfaengerFuerDateiname(vorgang(gegner: 'HUK Coburg')),
        'HUK Coburg',
      );
    });

    test('ohne beides null — und ohne Vorgang auch', () {
      expect(empfaengerFuerDateiname(vorgang()), isNull);
      expect(empfaengerFuerDateiname(null), isNull);
    });
  });

  group('naechsteSchreibenNummer', () {
    /// Beim ersten Schreiben gibt es nichts zu entscheiden.
    test('ohne bisheriges Schreiben immer 1', () {
      expect(naechsteSchreibenNummer(vorgang(), neuesSchreiben: false), 1);
      expect(naechsteSchreibenNummer(vorgang(), neuesSchreiben: true), 1);
      expect(naechsteSchreibenNummer(null, neuesSchreiben: true), 1);
    });

    test('eine Korrektur behält die Nummer', () {
      expect(
        naechsteSchreibenNummer(
          vorgang(schreibenNummer: 1),
          neuesSchreiben: false,
        ),
        1,
      );
    });

    test('ein neues Schreiben bekommt die nächste', () {
      expect(
        naechsteSchreibenNummer(
          vorgang(schreibenNummer: 1),
          neuesSchreiben: true,
        ),
        2,
      );
      expect(
        naechsteSchreibenNummer(
          vorgang(schreibenNummer: 7),
          neuesSchreiben: true,
        ),
        8,
      );
    });

    /// Ein unsinniger gespeicherter Wert (Altbestand, Handeingriff in der
    /// Datenbank) darf keine 0 oder negative Nummer in den Dateinamen tragen.
    test('ein Wert unter 1 zählt wie keiner', () {
      expect(
        naechsteSchreibenNummer(
          vorgang(schreibenNummer: 0),
          neuesSchreiben: true,
        ),
        1,
      );
    });
  });
}
