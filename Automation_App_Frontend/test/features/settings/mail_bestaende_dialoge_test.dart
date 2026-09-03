import 'package:automation_app/core/general_widgets/entfernen_rueckfrage.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/settings/presentation/widgets/anredebaustein_dialog.dart';
import 'package:automation_app/features/settings/presentation/widgets/grussformel_dialog.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_vorlage_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die drei Dialoge der Mail-Bestände (§4.7, §7.1) und die Rückfrage vor dem
/// Entfernen.
///
/// Der Mangel, den diese Datei festhält: Alle drei kehrten bei leerem
/// Pflichtfeld **wortlos** um. Kein Satz, keine Markierung, kein Fokussprung —
/// der Speichern-Knopf sah kaputt aus, und der Anwalt hatte keinen Anhalt,
/// was fehlt. Das Backend antwortet auf denselben Fall längst mit einem
/// brauchbaren deutschen Satz; die Wache davor verschluckte ihn.
void main() {
  Widget rahmen(Widget dialog) => MaterialApp(home: Scaffold(body: dialog));

  group('ein leeres Pflichtfeld wird benannt (§4.7)', () {
    testWidgets('der Gruß braucht einen Text', (tester) async {
      var gerufen = false;
      await tester.pumpWidget(
        rahmen(
          GrussformelDialog(
            grussformel: const Grussformel(),
            onSpeichern: (_) async {
              gerufen = true;
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pump();

      expect(find.text('Ohne Text gibt es nichts zu speichern.'), findsOne);
      expect(gerufen, isFalse, reason: 'nichts zu speichern, nichts gesendet');
    });

    testWidgets('die Meldung geht beim Tippen wieder weg', (tester) async {
      await tester.pumpWidget(
        rahmen(
          GrussformelDialog(
            grussformel: const Grussformel(),
            onSpeichern: (_) async => true,
          ),
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'Schalom');
      await tester.pump();

      expect(find.text('Ohne Text gibt es nichts zu speichern.'), findsNothing);
    });

    testWidgets('die Vorlage braucht einen Namen', (tester) async {
      var gerufen = false;
      await tester.pumpWidget(
        rahmen(
          MailVorlageDialog(
            vorlage: const MailVorlage(),
            onSpeichern: (_) async {
              gerufen = true;
              return true;
            },
          ),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pump();

      expect(
        find.text('Ohne Namen ist die Vorlage später nicht zu finden.'),
        findsOne,
      );
      expect(gerufen, isFalse);
    });

    testWidgets('der Anredeanfang braucht beide Formen', (tester) async {
      // Vorher fiel hier auch die **eine** ausgefüllte Form unter den Tisch:
      // Der Dialog blieb offen, der Knopf tat nichts, und beim Abbrechen war
      // die Eingabe weg.
      var gerufen = false;
      await tester.pumpWidget(
        rahmen(
          AnredebausteinDialog(
            baustein: const Anredebaustein(),
            onSpeichern: (_) async {
              gerufen = true;
              return true;
            },
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Männlich *'),
        'Moin',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pump();

      expect(
        find.text('Nötig — sonst ist die Anrede nur halb gebeugt.'),
        findsOne,
        reason: 'nur am leeren Feld, nicht an dem mit „Moin"',
      );
      expect(gerufen, isFalse);
    });
  });

  group('erst fragen, dann entfernen (§7.1)', () {
    /// Ein Knopf, der die Rückfrage stellt und ihre Antwort festhält — so
    /// ruft sie jeder der drei Abschnitte auf.
    Widget mitKnopf(void Function(bool) merke) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (kontext) => TextButton(
            onPressed: () async => merke(
              await EntfernenRueckfrage.gestellt(
                kontext,
                titel: 'Gruß entfernen?',
                text: '„Schalom" wird gelöscht.',
              ),
            ),
            child: const Text('los'),
          ),
        ),
      ),
    );

    testWidgets('„Entfernen" bestätigt', (tester) async {
      bool? antwort;
      await tester.pumpWidget(mitKnopf((wert) => antwort = wert));

      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      expect(find.text('Gruß entfernen?'), findsOne);

      await tester.tap(find.widgetWithText(FilledButton, 'Entfernen'));
      await tester.pumpAndSettle();

      expect(antwort, isTrue);
    });

    testWidgets('„Abbrechen" lässt den Eintrag stehen', (tester) async {
      bool? antwort;
      await tester.pumpWidget(mitKnopf((wert) => antwort = wert));

      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
      await tester.pumpAndSettle();

      expect(antwort, isFalse);
    });

    testWidgets('und die Escape-Taste zählt als „nein"', (tester) async {
      // null aus `showDialog` darf nicht als Zustimmung durchgehen.
      bool? antwort;
      await tester.pumpWidget(mitKnopf((wert) => antwort = wert));

      await tester.tap(find.text('los'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Abbrechen'))).pop();
      await tester.pumpAndSettle();

      expect(antwort, isFalse);
    });
  });
}
