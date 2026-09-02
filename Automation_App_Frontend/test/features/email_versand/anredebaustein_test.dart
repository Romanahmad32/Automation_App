import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Anredeanfang und seine drei Beugungsformen (§4.7, §7.1).
///
/// Der Fall, der diese Datei trägt: Gewählt wird **nur der Anfang**; „Herr"/
/// „Frau" und den Nachnamen setzt die App dazu, und die Beugung folgt dem
/// Geschlecht des Mandanten. Eine Form für alle hieße, jede zweite Mail falsch
/// anzureden.
void main() {
  const sehrGeehrt = Anredebaustein(
    id: 1,
    maennlich: 'Sehr geehrter',
    weiblich: 'Sehr geehrte',
    neutral: 'Sehr geehrte',
  );

  const gutenTag = Anredebaustein(
    id: 2,
    maennlich: 'Guten Tag',
    weiblich: 'Guten Tag',
    neutral: 'Guten Tag',
  );

  group('die Beugung folgt dem Mandanten', () {
    test('männlich bekommt „Herr" und die gebeugte Form', () {
      expect(
        sehrGeehrt.zeileFuer(
          anrede: Anrede.herr,
          nachname: 'Müller',
          persoenlich: true,
        ),
        'Sehr geehrter Herr Müller',
      );
    });

    test('weiblich bekommt „Frau" und die andere Form', () {
      expect(
        sehrGeehrt.zeileFuer(
          anrede: Anrede.frau,
          nachname: 'Schmitt',
          persoenlich: true,
        ),
        'Sehr geehrte Frau Schmitt',
      );
    });

    test('ein Anfang ohne Beugung darf dreimal gleich lauten', () {
      expect(
        gutenTag.zeileFuer(
          anrede: Anrede.herr,
          nachname: 'Müller',
          persoenlich: true,
        ),
        'Guten Tag Herr Müller',
      );
    });
  });

  group('wann neutral angeredet wird', () {
    test('ohne hinterlegtes Geschlecht — auch wenn persönlich erlaubt wäre', () {
      // Anrede.keine heisst: Wir wissen es nicht. Zu raten waere schlimmer als
      // die neutrale Form (§1.3).
      expect(
        sehrGeehrt.zeileFuer(
          anrede: Anrede.keine,
          nachname: 'Müller',
          persoenlich: true,
        ),
        'Sehr geehrte Damen und Herren',
      );
    });

    test('ohne Nachnamen steht die Anredeart allein da', () {
      // Geaendert am 03.09.2026 auf ausdruecklichen Auftrag: Vorher fiel diese
      // Lage auf „Sehr geehrte Damen und Herren" zurueck. Bei einem Vorgang
      // ohne Registermandanten sahen damit **alle** Chips gleich aus, und ein
      // Klick auf „Herr" bewegte nichts. Zu verschweigen ist hier auch nichts:
      // Ohne Namen verraet die Zeile niemanden.
      expect(
        sehrGeehrt.zeileFuer(
          anrede: Anrede.herr,
          nachname: '   ',
          persoenlich: true,
        ),
        'Sehr geehrter Herr',
      );
      expect(
        sehrGeehrt.zeileFuer(
          anrede: Anrede.frau,
          nachname: '',
          persoenlich: false,
        ),
        'Sehr geehrte Frau',
        reason:
            'ohne Namen gibt es keinen Mitleser, dem etwas verraten wuerde — '
            'der Empfaengerkreis entscheidet hier nichts mehr',
      );
    });

    test('„Keine Angabe" bleibt der Weg zur neutralen Form', () {
      expect(
        sehrGeehrt.zeileFuer(
          anrede: Anrede.keine,
          nachname: '',
          persoenlich: true,
        ),
        'Sehr geehrte Damen und Herren',
      );
    });

    test('wenn nicht persönlich angeredet werden soll', () {
      // Der Fall „die Versicherung liest mit" — und der Fall, in dem der
      // Anwalt es ausdruecklich so will (§4.7).
      expect(
        gutenTag.zeileFuer(
          anrede: Anrede.frau,
          nachname: 'Schmitt',
          persoenlich: false,
        ),
        'Guten Tag Damen und Herren',
      );
    });
  });

  test('ein leerer Anfang erzeugt keine Zeile mit Leerzeichen davor', () {
    const ohneAnfang = Anredebaustein(id: 3, neutral: '');

    expect(
      ohneAnfang.zeileFuer(
        anrede: Anrede.keine,
        nachname: '',
        persoenlich: false,
      ),
      'Damen und Herren',
    );
  });

  group('der Rückfall bei leerem Bestand', () {
    test('schreibt Wort für Wort dasselbe wie die feste Briefanrede', () {
      // Der Grund für diesen Test: `Anrede.briefanrede` bleibt bestehen, weil
      // sie `{{Anrede}}` in den **Word**-Vorlagen füllt. Zwei Wortlaute für
      // dieselbe Anrede laufen auseinander, sobald einer angefasst wird — hier
      // fällt es auf, bevor eine Mail und ein Schreiben verschieden anreden.
      for (final anrede in Anrede.values) {
        expect(
          Anredebaustein.rueckfall.zeileFuer(
            anrede: anrede,
            nachname: 'Müller',
            persoenlich: true,
          ),
          anrede.briefanrede('Müller'),
          reason: 'für ${anrede.value}',
        );
      }
    });

    test('folgt der gewählten Anredeart — anders als vorher', () {
      // Der behobene Fehler (02.09.2026): Ohne Bestand lief die Anredezeile
      // über `Mandant.briefanrede`, und die liest nur das Register. Wer für
      // diese eine Mail „Frau" wählte, bekam „unserer Mandantin" im Text und
      // „Sehr geehrte Damen und Herren" darüber.
      expect(
        Anredebaustein.rueckfall.zeileFuer(
          anrede: Anrede.frau,
          nachname: 'Schmitt',
          persoenlich: true,
        ),
        'Sehr geehrte Frau Schmitt',
      );
    });

    test('ist der erste des Ausgangsbestands', () {
      // Er muss dem Seed des Dienstes gleichen (`AnredeBausteineVorgabe`),
      // sonst wechselt die Anrede beim ersten erfolgreichen Laden.
      expect(Anredebaustein.rueckfall.maennlich, 'Sehr geehrter');
      expect(Anredebaustein.rueckfall.weiblich, 'Sehr geehrte');
      expect(Anredebaustein.rueckfall.neutral, 'Sehr geehrte');
      expect(
        Anredebaustein.rueckfall.istGespeichert,
        isFalse,
        reason: 'er steht in keinem Bestand und darf keinen Chip auswählen',
      );
    });
  });

  test('die Bezeichnung ist die männliche Form — sie ist die gebeugte', () {
    expect(sehrGeehrt.bezeichnung, 'Sehr geehrter');
  });

  test('JSON trägt alle drei Formen', () {
    final zurueck = Anredebaustein.fromJson({
      'id': 7,
      'maennlich': 'Lieber',
      'weiblich': 'Liebe',
      'neutral': 'Liebe',
      'sortierung': 30,
    });

    expect(zurueck.maennlich, 'Lieber');
    expect(zurueck.weiblich, 'Liebe');
    expect(zurueck.neutral, 'Liebe');
    expect(zurueck.sortierung, 30);
    expect(zurueck.istGespeichert, isTrue);
    // Die Id gehoert in den Pfad, nicht in den Rumpf — wie bei `Grussformel`.
    expect(zurueck.toJson().containsKey('id'), isFalse);
  });
}
