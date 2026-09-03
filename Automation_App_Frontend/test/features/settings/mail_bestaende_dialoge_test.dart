import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/settings/presentation/widgets/anredebaustein_dialog.dart';
import 'package:automation_app/features/settings/presentation/widgets/grussformel_dialog.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_vorlage_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die drei Dialoge der Mail-Bestände (§4.7, §7.1).
///
/// Der Mangel, den diese Datei festhält: Alle drei kehrten bei leerem
/// Pflichtfeld **wortlos** um. Kein Satz, keine Markierung, kein Fokussprung —
/// der Speichern-Knopf sah kaputt aus, und der Anwalt hatte keinen Anhalt,
/// was fehlt. Das Backend antwortet auf denselben Fall längst mit einem
/// brauchbaren deutschen Satz; die Wache davor verschluckte ihn.
///
/// Die Rückfrage vor dem Entfernen steht **nicht** hier: Sie läuft über
/// `bestaetigen` aus `core/general_widgets/`, und die hat ihren eigenen Test
/// (`bestaetigungs_dialog_test.dart`). Ein zweiter daneben prüfte fremden
/// Code.
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
}
