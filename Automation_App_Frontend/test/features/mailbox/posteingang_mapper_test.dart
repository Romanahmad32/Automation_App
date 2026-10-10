import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Feldnamen sind der halbe Vertrag zum Backend (§5.1): Sie stehen nur als
/// Zeichenketten in beiden Quellen, und ein Tippfehler fällt zur Laufzeit als
/// leeres Feld auf, nicht beim Übersetzen. Deshalb je ein Beispiel aus der
/// Antwort des Dienstes.
void main() {
  test('Ein Listeneintrag liest Absender, Empfänger und Anhangszahl', () {
    final eintrag = PosteingangEintrag.fromJson(const {
      'id': 'kennung',
      'betreff': 'Ihre Anfrage',
      'absender': '"Max Muster" <max@x.de>',
      'absenderName': 'Max Muster',
      'absenderAdresse': 'max@x.de',
      'an': ['kanzlei@x.de'],
      'cc': ['kopie@x.de'],
      'messageId': 'abc@mail',
      'datum': '2026-09-13T08:30:00Z',
      'gelesen': true,
      'groesse': 4096,
      'hatAnhaenge': true,
      'anzahlAnhaenge': 2,
    });

    expect(eintrag.absenderName, 'Max Muster');
    expect(eintrag.absenderAdresse, 'max@x.de');
    expect(eintrag.an, ['kanzlei@x.de']);
    expect(eintrag.cc, ['kopie@x.de']);
    expect(eintrag.messageId, 'abc@mail');
    expect(eintrag.hatAnhaenge, isTrue);
    expect(eintrag.anzahlAnhaenge, 2);
    expect(eintrag.datum, isNotNull);
  });

  test('Fehlende neue Felder machen aus einem Eintrag keinen Fehler', () {
    final eintrag = PosteingangEintrag.fromJson(const {
      'id': 'kennung',
      'betreff': 'Ihre Anfrage',
      'absender': 'max@x.de',
    });

    expect(eintrag.an, isEmpty);
    expect(eintrag.cc, isEmpty);
    expect(eintrag.messageId, isNull);
    expect(eintrag.hatAnhaenge, isFalse);
    expect(eintrag.anzahlAnhaenge, 0);
    expect(eintrag.gelesen, isFalse);
    expect(eintrag.groesse, 0);
  });

  test('Der Inhalt trägt beide Fassungen und beschriebene Anhänge', () {
    final inhalt = PosteingangInhalt.fromJson(const {
      'text': 'Guten Tag',
      'gekuerzt': false,
      'html': '<p>Guten Tag</p>',
      'htmlGekuerzt': false,
      'absenderName': 'Max Muster',
      'absenderAdresse': 'max@x.de',
      'an': ['kanzlei@x.de'],
      'cc': <String>[],
      'datum': '2026-09-13T08:30:00Z',
      'messageId': 'abc@mail',
      'anhaenge': [
        {
          'id': '2',
          'dateiname': 'Gutachten.pdf',
          'groesse': 120000,
          'medientyp': 'application/pdf',
        },
      ],
    });

    expect(inhalt.hatHtml, isTrue);
    expect(inhalt.messageId, 'abc@mail');
    expect(inhalt.anhaenge.single.id, '2');
    expect(inhalt.anhaenge.single.dateiname, 'Gutachten.pdf');
    expect(inhalt.anhaenge.single.groesse, 120000);
    expect(inhalt.anhaenge.single.medientyp, 'application/pdf');
  });

  test('Ohne HTML-Fassung bleibt der Umschalter ohne Angebot', () {
    final inhalt = PosteingangInhalt.fromJson(const {
      'text': 'Nur Text',
      'gekuerzt': true,
    });

    expect(inhalt.html, isNull);
    expect(inhalt.hatHtml, isFalse);
    expect(inhalt.gekuerzt, isTrue);
    expect(inhalt.anhaenge, isEmpty);
  });

  test('bilderBlockiert kommt als eigenes Feld an, nicht aus dem HTML', () {
    expect(
      PosteingangInhalt.fromJson(const {
        'text': 'Text',
        'html': '<p>Text</p>',
        'bilderBlockiert': true,
      }).bilderBlockiert,
      isTrue,
    );
    expect(
      PosteingangInhalt.fromJson(const {
        'text': 'Text',
        'html': '<p>Text</p>',
        'bilderBlockiert': false,
      }).bilderBlockiert,
      isFalse,
    );
    expect(
      PosteingangInhalt.fromJson(const {'text': 'Text', 'html': '<p>Text</p>'})
          .bilderBlockiert,
      isFalse,
    );
  });

  test('Eine abgelegte Datei kommt als Pfad zurück, nicht als Inhalt', () {
    final ablage = PosteingangAnhangAblage.fromJson(const {
      'dateiname': 'Gutachten.pdf',
      'pfad':
          r'C:\Users\x\AppData\Roaming\AutomationService\Anhaenge'
          r'\Posteingang\konto\12\Gutachten.pdf',
      'groesse': 120000,
    });

    expect(ablage.dateiname, 'Gutachten.pdf');
    expect(ablage.pfad, contains('Posteingang'));
    expect(ablage.groesse, 120000);
  });

  test('Ein Anhang ohne Namen bekommt eine Ersatzbezeichnung', () {
    final anhang = PosteingangAnhang.fromJson(const {'id': '2.1'});

    expect(anhang.dateiname, 'Anhang');
    expect(anhang.groesse, 0);
    expect(anhang.medientyp, isEmpty);
  });

  test('Die erfasste Antwort trägt den Mailschlüssel für den Abgleich', () {
    final reply = ReceivedReply.fromJson(const {
      'id': '17',
      'receivedAt': '2026-09-13T08:30:00Z',
      'subject': 'Zentralruf',
      'from': 'zentralruf@gdv.de',
      'acknowledged': false,
      'data': <String, dynamic>{},
      'warnings': <String>[],
      'mailSchluessel': 'abc@mail',
    });

    expect(reply.mailSchluessel, 'abc@mail');
  });
}
