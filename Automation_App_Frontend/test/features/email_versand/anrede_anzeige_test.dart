import 'package:automation_app/features/email_versand/domain/entities/anrede_neutral_grund.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_bestand_fehler.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_bestand_leer.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_neutral_grund_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was der Anwalt über die **neutrale Anrede** zu sehen bekommt (§4.7) — und
/// was an der Stelle der Chipreihe steht, wenn der Bestand nicht geladen
/// werden konnte.
///
/// Geprüft wird die Entscheidung, nicht das Aussehen: welcher Satz erscheint,
/// und dass eine Lücke im Register als Aufgabe erkennbar ist. Beides war
/// vorher gar nicht zu sehen — die Zeile war neutral, und niemand sagte,
/// weshalb.
void main() {
  Widget rahmen(Widget kind) => MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: kind)),
  );

  group('der Grund unter der Chipreihe', () {
    testWidgets('nennt den Mitleser ohne Zeichen — die Mail stimmt so', (
      tester,
    ) async {
      await tester.pumpWidget(
        rahmen(
          const AnredeNeutralGrundZeile(grund: AnredeNeutralGrund.mitleser),
        ),
      );

      expect(find.textContaining('noch jemand im Feld'), findsOneWidget);
      expect(
        find.byIcon(Icons.info_outline),
        findsNothing,
        reason: 'der Empfängerkreis ist keine Aufgabe, sondern eine Auskunft',
      );
    });

    testWidgets('markiert die Lücke im Register', (tester) async {
      await tester.pumpWidget(
        rahmen(
          const AnredeNeutralGrundZeile(grund: AnredeNeutralGrund.keineAdresse),
        ),
      );

      expect(find.textContaining('keine E-Mail-Adresse'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('jeder Grund beginnt mit „Neutral, weil"', (tester) async {
      // Die Auskunft muss auch beim Überfliegen an der Zeile kleben, die sie
      // erklärt.
      for (final grund in AnredeNeutralGrund.values) {
        expect(grund.hinweis, startsWith('Neutral, weil'), reason: grund.name);
      }
    });
  });

  group('eine Vorlage ohne Stelle für die Anrede', () {
    test('nennt den Platzhalter und die Folge', () {
      // Fehlt `{{Anrede}}`, geht die Mail **ohne Anredezeile** hinaus — und
      // beide Reihen darüber sind wirkungslos. Bis zum 02.09.2026 sagte das
      // niemand, obwohl derselbe Satz für den Zusatzgruß längst dastand.
      final hinweis = AnredeChips.hinweisFuer(
        const EmailEntwurfState(
          gewaehlteVorlage: MailVorlage(
            id: 1,
            name: 'Ohne Anrede',
            betreff: 'Betreff',
            text: 'Kein Platz für die Anrede.',
          ),
        ),
      );

      expect(hinweis, contains('{{Anrede}}'));
      expect(hinweis, contains('ohne Anredezeile'));
    });

    test('mit Stelle und ohne Vorlage bleibt es still', () {
      expect(
        AnredeChips.hinweisFuer(
          const EmailEntwurfState(
            gewaehlteVorlage: MailVorlage(
              id: 2,
              name: 'Mit Anrede',
              text: '{{Anrede}},\n\nText.',
            ),
          ),
        ),
        isNull,
      );
      expect(
        AnredeChips.hinweisFuer(const EmailEntwurfState()),
        isNull,
        reason:
            'ohne Vorlage gilt die Vorbelegung, und die hat immer eine '
            'Anredezeile',
      );
    });
  });

  group('der Bestand liess sich nicht laden', () {
    test('der Satz nennt die Meldung des Dienstes', () {
      expect(
        AnredeBestandFehler.text('Verbindung abgelehnt (Port 5143)'),
        contains('Verbindung abgelehnt (Port 5143)'),
      );
    });

    testWidgets('nennt den Rückfall und lässt es erneut versuchen', (
      tester,
    ) async {
      var erneut = 0;
      await tester.pumpWidget(
        rahmen(
          AnredeBestandFehler(
            fehler: 'Verbindung abgelehnt',
            onErneut: () => erneut++,
          ),
        ),
      );

      expect(find.textContaining('nicht laden'), findsOneWidget);
      expect(find.textContaining('Sehr geehrter/Sehr geehrte'), findsOneWidget);

      await tester.tap(find.text('Erneut versuchen'));

      expect(erneut, 1);
    });

    testWidgets('während der Dialog arbeitet, ist der Knopf gesperrt', (
      tester,
    ) async {
      await tester.pumpWidget(
        rahmen(
          AnredeBestandFehler(
            fehler: 'Verbindung abgelehnt',
            aktiv: false,
            onErneut: () {},
          ),
        ),
      );

      final knopf = tester.widget<TextButton>(find.byType(TextButton));
      expect(knopf.onPressed, isNull);
    });
  });

  group('es ist keine Anrede angelegt', () {
    test('der Satz nennt, was stattdessen gilt, und wo man es ändert', () {
      // Der leere Bestand galt als selbsterklaerend. War er nicht: Geloescht
      // ist der Bestand, nicht die Anredezeile — `Anredebaustein.rueckfall`
      // schreibt weiter. Die Reihe verschwand, die Anrede blieb.
      expect(AnredeBestandLeer.text, contains('keine Anrede angelegt'));
      expect(AnredeBestandLeer.text, contains('Sehr geehrter/Sehr geehrte'));
      expect(AnredeBestandLeer.text, contains('Einstellungen'));
    });

    testWidgets('steht an der Stelle der Chipreihe', (tester) async {
      await tester.pumpWidget(rahmen(const AnredeBestandLeer()));

      expect(find.text('Anrede'), findsOneWidget);
      expect(find.textContaining('keine Anrede angelegt'), findsOneWidget);
      expect(
        find.byType(TextButton),
        findsNothing,
        reason: 'kein Sprung in die Einstellungen — das verwuerfe den Entwurf',
      );
    });
  });
}
