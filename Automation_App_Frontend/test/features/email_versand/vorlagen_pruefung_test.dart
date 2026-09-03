import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/vorlagen_pruefung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was der Vorlageneditor über die eben getippte Vorlage sagt (§4.7).
///
/// Der Fall, der diese Datei trägt: Dieselbe Auskunft gab es bisher nur im
/// Versanddialog — also Wochen später, an einer Vorlage, die längst als fertig
/// galt, und unter einer Mail, die gleich hinausgehen soll. Hier steht sie
/// unter dem Feld, in dem der Name gerade getippt wurde.
void main() {
  MailVorlage mit({String betreff = '', String text = ''}) =>
      MailVorlage(id: 1, name: 'Probe', betreff: betreff, text: text);

  group('Platzhalter, die nichts liefern werden', () {
    test('ein unbekannter Name wird benannt', () {
      final maengel = VorlagenPruefung.maengel(
        mit(text: 'Anschrift: {{Adresse}}'),
      );

      expect(maengel.single.geschrieben, '{{Adresse}}');
      expect(maengel.single.hinweis, contains('kein Feld dieses Namens'));
    });

    test('gültige Namen ergeben keinen Mangel', () {
      final maengel = VorlagenPruefung.maengel(
        mit(
          betreff: 'Unser Zeichen: {{Referenz}}',
          text: '{{Anrede}},\n{{Zusatzgruß}},\n{{MandantName}} · {{Unfallort}}',
        ),
      );

      expect(
        maengel,
        isEmpty,
        reason:
            'Anrede und Zusatzgruß stehen in keinem Datenquellen-Katalog und '
            'dürfen trotzdem nirgends als unbekannt gelten',
      );
    });

    test('der Betreff wird mitgeprüft, und zuerst', () {
      final maengel = VorlagenPruefung.maengel(
        mit(betreff: '{{Adresse}}', text: '{{Telefonnummer}}'),
      );

      expect(maengel.map((mangel) => mangel.platzhalter), [
        'Adresse',
        'Telefonnummer',
      ]);
    });

    test('jeder Name nur einmal, auch bei anderer Schreibweise', () {
      final maengel = VorlagenPruefung.maengel(
        mit(text: '{{Adresse}} und {{adresse}} und {{Adresse}}'),
      );

      expect(maengel, hasLength(1));
    });

    test('ein Name, der nach zwei Angaben klingt, bekommt seinen Satz', () {
      // Den kennt `FeldDatenquelleErkennung` selbst — hier nicht daneben neu
      // erfinden, sondern durchreichen.
      final maengel = VorlagenPruefung.maengel(
        mit(text: '{{VersicherungPlzOrt}}'),
      );

      expect(maengel.single.hinweis, isNotEmpty);
      expect(
        maengel.single.hinweis,
        isNot(contains('kein Feld dieses Namens')),
      );
    });
  });

  group('Beugungen', () {
    test('eine unvollständige wird als Beugung beurteilt', () {
      final maengel = VorlagenPruefung.maengel(mit(text: '{{Mandant/}}'));

      expect(maengel.single.hinweis, contains('Beugung unvollständig'));
      expect(
        maengel.single.hinweis,
        isNot(contains('kein Feld dieses Namens')),
        reason: 'der Name ist richtig, die Formen sind es nicht',
      );
    });

    test('eine geglückte ist kein Mangel', () {
      expect(
        VorlagenPruefung.maengel(mit(text: '{{Mandant/Mandantin}} {{er/sie}}')),
        isEmpty,
      );
    });

    test('die häufigsten Beugungen werden nicht beanstandet', () {
      // Die Falle, die ein erster Entwurf dieser Prüfung gestellt hat:
      // `FeldDatenquelleErkennung` ist eine Heuristik über Teilzeichenketten
      // und löst „Mandant", „Mandantin" und „Geschädigter" **alle** auf
      // „Mandant · Name" auf. Wer sie hier fragt, beanstandet ausgerechnet
      // das Beispiel aus der Auswahlliste.
      expect(
        VorlagenPruefung.maengel(
          mit(
            text:
                '{{Mandant/Mandantin}} {{Geschädigter/Geschädigte}} '
                '{{unser/unsere}} {{sein/ihr}}',
          ),
        ),
        isEmpty,
      );
    });

    test('ein Feldname als erste Form ist fast sicher keine Beugung', () {
      // Der Preis der Schrägstrich-Schreibweise, hier eingefangen:
      // `{{MandantOrt/MandantPlz}}` setzt sonst das Wort „MandantOrt" ein.
      final maengel = VorlagenPruefung.maengel(
        mit(text: '{{MandantOrt/MandantPlz}}'),
      );

      expect(maengel.single.hinweis, contains('ist selbst ein Feldname'));
      expect(
        maengel.single.hinweis,
        contains('zwei Platzhalter'),
        reason: 'der Satz muss sagen, was stattdessen zu tun ist',
      );
    });

    test('beugungen liefert nur die geglückten, in Reihenfolge', () {
      final beugungen = VorlagenPruefung.beugungen(
        mit(
          betreff: '{{unseres/unserer}}',
          text: '{{Mandant/Mandantin}} und {{Mandant/}} und {{er/sie}}',
        ),
      );

      expect(
        beugungen.map((beugung) => beugung.maennlich),
        ['unseres', 'Mandant', 'er'],
        reason: 'die misslungene gehört in die Mängel, nicht in die Vorschau',
      );
    });

    test('ohne Beugung ist die Liste leer', () {
      expect(VorlagenPruefung.beugungen(mit(text: '{{MandantName}}')), isEmpty);
    });
  });
}
