import 'package:automation_app/features/email_versand/domain/entities/anrede_neutral_grund.dart';
import 'package:automation_app/features/email_versand/domain/services/email_entwurf_erzeuger.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Warum** die Anrede einer Mail neutral ausfällt (§4.7) — und dass der
/// Rückfall der gewählten Anredeart folgt.
///
/// Der Bericht aus der Kanzlei, der diese Datei trägt: „Sehr geehrte Damen und
/// Herren" stand über Mails, obwohl niemand diese Anrede angelegt hatte, und
/// ein Klick auf die Anredeart bewegte sie nicht. Beides war für sich richtig —
/// die neutrale Zeile hat kein Geschlecht — aber die App kannte den Grund und
/// sagte ihn nicht. Sechs Lagen führen zur neutralen Anrede, und nur eine
/// davon hat der Anwalt gewählt.
void main() {
  const kanzlei = KanzleiSettings(name: 'Rechtsanwalt Max Muster');

  Mandant mandant({
    Anrede anrede = Anrede.herr,
    String nachname = 'Müller',
    String email = 'k.mueller@example.de',
  }) => Mandant(
    id: 7,
    anrede: anrede,
    vorname: 'Klaus',
    nachname: nachname,
    emailAdresse: email,
    erstelltAm: DateTime(2026, 1, 1),
  );

  EmailEntwurfErzeuger erzeuger({Mandant? mit}) =>
      EmailEntwurfErzeuger(kanzlei: kanzlei, mandant: mit);

  group('kein Grund — die Anrede ist namentlich oder so gewollt', () {
    test('nur der Mandant im Feld „An", alles hinterlegt', () {
      expect(
        erzeuger(mit: mandant()).neutralGrund(const ['k.mueller@example.de']),
        isNull,
      );
    });

    test('der Anwalt hat „neutral anreden" selbst angehakt', () {
      // Seine Entscheidung braucht keine Erklärung — das Häkchen steht daneben.
      expect(
        erzeuger(
          mit: mandant(),
        ).neutralGrund(const ['k.mueller@example.de'], neutral: true),
        isNull,
      );
    });

    test('der Anwalt hat „Keine Angabe" als Anredeart gewählt', () {
      // Dieselbe Ausnahme, zunächst vergessen: `keine` entsteht auf zwei
      // Wegen. Steht am Mandanten nichts, ist es eine Lücke — ist sie
      // **gewählt**, hielte die Meldung dem Anwalt seine eigene Wahl vor.
      expect(
        erzeuger(mit: mandant()).neutralGrund(const [
          'k.mueller@example.de',
        ], geschlecht: Anrede.keine),
        isNull,
      );
    });
  });

  group('der Empfängerkreis — dann ist die neutrale Anrede richtig', () {
    test('die Versicherung liest mit', () {
      expect(
        erzeuger(
          mit: mandant(),
        ).neutralGrund(const ['k.mueller@example.de', 'schaden@huk.de']),
        AnredeNeutralGrund.mitleser,
      );
    });

    test('das Feld „An" ist noch leer — und das ist kein Mitleser', () {
      // Der Einstieg aus dem Postfach: Der Entwurf steht, die Adresse noch
      // nicht. „Neben dem Mandanten steht noch jemand" wäre hier falsch.
      expect(
        erzeuger(mit: mandant()).neutralGrund(const []),
        AnredeNeutralGrund.keinEmpfaenger,
      );
    });

    test('kein Grund ist eine Lücke, die nachzupflegen wäre', () {
      expect(AnredeNeutralGrund.mitleser.istLuecke, isFalse);
      expect(AnredeNeutralGrund.keinEmpfaenger.istLuecke, isFalse);
    });
  });

  group('die Lücken — dann ist die neutrale Anrede eine Aufgabe', () {
    test('kein Mandant zum Vorgang', () {
      expect(
        erzeuger().neutralGrund(const ['k.mueller@example.de']),
        AnredeNeutralGrund.keinMandant,
      );
    });

    test('der Mandant hat keine E-Mail-Adresse — obwohl sie dort steht', () {
      // Die teuerste der sechs Lagen: Die App erkennt den Mandanten im Feld
      // „An" **nur** an seiner hinterlegten Adresse. Ist dort keine, gehört
      // die von Hand eingetippte für sie zu einem Fremden — und die Mail an
      // den Mandanten beginnt neutral, ohne dass jemand den Grund sieht.
      expect(
        erzeuger(
          mit: mandant(email: ''),
        ).neutralGrund(const ['k.mueller@example.de']),
        AnredeNeutralGrund.keineAdresse,
      );
    });

    test('kein Nachname — und keine Anredeart, die einspringt', () {
      // Geaendert am 03.09.2026: Ohne Nachnamen traegt eine **gewaehlte**
      // Anredeart die Zeile allein („Sehr geehrter Herr"), dann ist sie nicht
      // neutral. Eine Luecke bleibt es nur, wenn auch die Anredeart fehlt.
      expect(
        erzeuger(
          mit: mandant(nachname: '  ', anrede: Anrede.keine),
        ).neutralGrund(const ['k.mueller@example.de']),
        AnredeNeutralGrund.keinNachname,
      );
    });

    test('ohne Nachnamen traegt die Anredeart die Zeile allein', () {
      expect(
        erzeuger(
          mit: mandant(nachname: '  '),
        ).neutralGrund(const ['k.mueller@example.de']),
        isNull,
        reason: 'die Zeile lautet „Sehr geehrter Herr" und ist nicht neutral',
      );
      expect(
        erzeuger().neutralGrund(const [
          'unbekannt@example.de',
        ], geschlecht: Anrede.frau),
        isNull,
        reason:
            'auch ohne Mandanten im Register: gewaehlt ist gewaehlt, und die '
            'Chipreihe zeigt es',
      );
    });

    test('keine Anredeart — und sie ist mit einem Klick behoben', () {
      final ohneAngabe = erzeuger(mit: mandant(anrede: Anrede.keine));

      expect(
        ohneAngabe.neutralGrund(const ['k.mueller@example.de']),
        AnredeNeutralGrund.keineAnredeart,
      );
      expect(
        ohneAngabe.neutralGrund(const [
          'k.mueller@example.de',
        ], geschlecht: Anrede.frau),
        isNull,
        reason: 'die für diese Mail gewählte Anredeart füllt die Lücke',
      );
    });

    test('eine Lücke bleibt sichtbar, auch wenn er namentlich erzwingt', () {
      // `neutral: false` heisst „namentlich anreden" — es stellt aber keinen
      // Nachnamen her. Ohne Anredeart bleibt die Zeile neutral, also bleibt
      // der Grund stehen.
      expect(
        erzeuger(
          mit: mandant(nachname: '', anrede: Anrede.keine),
        ).neutralGrund(const ['k.mueller@example.de'], neutral: false),
        AnredeNeutralGrund.keinNachname,
      );
    });

    test('jede Lücke ist als solche erkennbar', () {
      for (final grund in [
        AnredeNeutralGrund.keinMandant,
        AnredeNeutralGrund.keineAdresse,
        AnredeNeutralGrund.keinNachname,
        AnredeNeutralGrund.keineAnredeart,
      ]) {
        expect(grund.istLuecke, isTrue, reason: grund.name);
      }
    });
  });

  group('der Umschalter „neutral anreden" hat etwas zu schalten', () {
    test('auch bei einer Mail an die Versicherung', () {
      // Der Mangel: Angeboten wurde er nur, wenn die namentliche Anrede
      // **schon** galt — also nie, wenn man ihn braucht. „Änderbar" heisst
      // änderbar (§4.7).
      expect(erzeuger(mit: mandant()).anredeNamentlichMachbar(), isTrue);
      expect(
        erzeuger(mit: mandant()).anredePersoenlichMoeglich(const [
          'k.mueller@example.de',
          'schaden@huk.de',
        ]),
        isFalse,
        reason:
            'der Empfängerkreis ergibt die neutrale Anrede — der '
            'Umschalter steht trotzdem zur Verfügung',
      );
    });

    test('nicht ohne Nachnamen und nicht ohne Anredeart', () {
      expect(
        erzeuger(mit: mandant(nachname: '')).anredeNamentlichMachbar(),
        isFalse,
      );
      expect(
        erzeuger(mit: mandant(anrede: Anrede.keine)).anredeNamentlichMachbar(),
        isFalse,
      );
      expect(erzeuger().anredeNamentlichMachbar(), isFalse);
    });

    test('die gewählte Anredeart macht ihn wieder schaltbar', () {
      expect(
        erzeuger(
          mit: mandant(anrede: Anrede.keine),
        ).anredeNamentlichMachbar(geschlecht: Anrede.frau),
        isTrue,
      );
    });
  });

  group('der Rückfall ohne Bestand folgt der Anredeart', () {
    test('die gewählte Form schlägt den leeren Registereintrag', () {
      // Der behobene Fehler: Ohne Anredebestand lief die Zeile über
      // `Mandant.briefanrede` und las nur das Register. Wer „Frau" wählte,
      // bekam „unserer Mandantin" im Text und „Sehr geehrte Damen und Herren"
      // darüber.
      expect(
        erzeuger(
          mit: mandant(anrede: Anrede.keine),
        ).anredeFuer(const ['k.mueller@example.de'], geschlecht: Anrede.frau),
        'Sehr geehrte Frau Müller',
      );
    });

    test('ohne Wahl bleibt es beim Registereintrag', () {
      expect(
        erzeuger(mit: mandant()).anredeFuer(const ['k.mueller@example.de']),
        'Sehr geehrter Herr Müller',
      );
    });

    test('ohne Mandanten bleibt die Zeile neutral', () {
      expect(
        erzeuger().anredeFuer(const ['schaden@huk.de']),
        'Sehr geehrte Damen und Herren',
      );
    });
  });
}
