import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Versicherer` spiegelt `VersichererDto` von Hand (siehe gespiegelteDtos in
/// `test/architecture/http_vertrag_test.dart`). Der Vertragstest hält die
/// Feld*namen* fest — hier steht, was aus den Werten wird.
void main() {
  Map<String, dynamic> antwort({
    String? zuletztAktualisiertAm,
    String? strasse,
  }) => {
    'id': 4,
    'name': 'HUK-COBURG',
    'strasse': strasse,
    'plz': '96444',
    'ort': 'Coburg',
    'telefon': null,
    'fax': null,
    'email': null,
    'zuletztAktualisiertAm': zuletztAktualisiertAm,
    'quelle': 'Zentralruf-Antwort zur Anfrage vom 12.06.2026',
  };

  test('übernimmt Pflicht- und Kontaktfelder', () {
    final versicherer = Versicherer.fromJson(
      antwort(strasse: 'Bahnhofsplatz 1'),
    );

    expect(versicherer.id, 4);
    expect(versicherer.name, 'HUK-COBURG');
    expect(versicherer.strasse, 'Bahnhofsplatz 1');
    expect(versicherer.plz, '96444');
    expect(versicherer.ort, 'Coburg');
    expect(versicherer.quelle, contains('12.06.2026'));
  });

  test('fehlende Kontaktfelder bleiben null statt leerer Zeichenkette', () {
    // Der Unterschied zählt: „nicht bekannt" lässt die Ergänzung aus
    // zentralruf_reply die Lücke füllen, ein leerer Text gilt als Angabe.
    final versicherer = Versicherer.fromJson(antwort());

    expect(versicherer.strasse, isNull);
    expect(versicherer.telefon, isNull);
    expect(versicherer.fax, isNull);
    expect(versicherer.email, isNull);
  });

  group('zuletztAktualisiertAm', () {
    test('kommt als Ortszeit an, nicht als UTC', () {
      // Das Backend liefert UTC; angezeigt wird der Stand im Herkunftshinweis
      // („Stand 12.06.2026"). Ohne toLocal() steht dort abends das Datum von
      // morgen.
      final versicherer = Versicherer.fromJson(
        antwort(zuletztAktualisiertAm: '2026-06-12T22:30:00Z'),
      );

      expect(versicherer.zuletztAktualisiertAm!.isUtc, isFalse);
      expect(
        versicherer.zuletztAktualisiertAm!.toUtc(),
        DateTime.utc(2026, 6, 12, 22, 30),
      );
    });

    test('fehlend oder unlesbar heißt: kein Stand, nicht Absturz', () {
      // Der Wert ist im DTO optional, und das Register wird automatisch
      // befüllt — ein Eintrag ohne Stand darf die Antwortauswertung nicht
      // beim Parsen abbrechen.
      expect(Versicherer.fromJson(antwort()).zuletztAktualisiertAm, isNull);
      expect(
        Versicherer.fromJson(
          antwort(zuletztAktualisiertAm: 'unbekannt'),
        ).zuletztAktualisiertAm,
        isNull,
      );
    });
  });
}
