import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/utils/platzhalter_einfuege_ziel.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/betreff_text_felder.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_inhalt.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_vorschau.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/versand_bereitschaft_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'versand_doubles.dart';

/// Die Gestalt des Versanddialogs (§4.7, Issue #107): drei benannte Abschnitte,
/// die Vorschau **im Dialog** statt hinter einem zweiten Fenster, und die
/// Versandbereitschaft **vor** dem Klick auf Senden.
///
/// Geprüft werden die Entscheidungen, nicht das Aussehen: dass der Umschalter
/// ohne Zutun dasteht, dass die Vorschau danach im selben Dialog steht, dass
/// die drei Überschriften da sind und dass die Statuszeile den ersten offenen
/// Punkt nennt, bevor jemand gedrückt hat.
void main() {
  setUp(registriereVersandBestaende);

  tearDown(() => getIt.reset());

  /// Zeigt den Rumpf des Dialogs in einem Fenster der Größe [breite] × 900.
  /// Die Schwelle für zwei Spalten liegt bei 1180 px — darunter ist „schmal".
  Future<EmailEntwurfCubit> zeige(
    WidgetTester tester, {
    required double breite,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(breite, 900);
    addTearDown(tester.view.reset);

    final cubit = stummerEntwurfCubit();
    addTearDown(cubit.close);
    await cubit.starte();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider<EmailEntwurfCubit>.value(
            value: cubit,
            child: BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
              builder: (context, state) => EmailVersandInhalt(state: state),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  group('die Vorschau steckt nicht mehr hinter einem zweiten Fenster', () {
    testWidgets('auf schmalem Fenster steht der Umschalter ohne Zutun da', (
      tester,
    ) async {
      // Der Mangel: Unter 1180 px war die Vorschau nur über einen Knopf in der
      // Fußzeile zu haben, und der öffnete einen **eigenen** Dialog — wer
      // prüfen wollte, verliess dafür das Formular. §4.7 verlangt die
      // Sichtprüfung, während geschrieben wird.
      await zeige(tester, breite: 900);

      expect(find.text('Vorschau'), findsOneWidget);
      expect(find.text('Bearbeiten'), findsOneWidget);
      expect(
        find.byType(Dialog),
        findsNothing,
        reason: 'nichts öffnet sich, der Umschalter steht im Formular',
      );
    });

    testWidgets('ein Klick zeigt sie im selben Dialog', (tester) async {
      await zeige(tester, breite: 900);
      expect(find.byType(EmailVorschau), findsNothing);

      await tester.tap(find.text('Vorschau'));
      await tester.pumpAndSettle();

      expect(find.byType(EmailVorschau), findsOneWidget);
      expect(
        find.byType(Dialog),
        findsNothing,
        reason: 'sie steht an der Stelle des Formulars, nicht darüber',
      );
    });

    testWidgets('auf breitem Fenster steht sie ganz ohne Klick daneben', (
      tester,
    ) async {
      await zeige(tester, breite: 1300);

      expect(find.byType(EmailVorschau), findsOneWidget);
      // Und das Formular daneben: Beides gleichzeitig ist der Sinn der
      // zweiten Spalte.
      expect(find.text('Empfänger'), findsOneWidget);
    });
  });

  group('drei benannte Abschnitte statt fünfzehn Blöcken', () {
    testWidgets('Empfänger, Inhalt und Anhänge tragen Überschriften', (
      tester,
    ) async {
      await zeige(tester, breite: 900);

      expect(find.text('Empfänger'), findsOneWidget);
      expect(find.text('Inhalt'), findsOneWidget);
      expect(find.text('Anhänge'), findsOneWidget);
    });
  });

  group('die Versandbereitschaft steht vor dem Klick', () {
    testWidgets('der erste offene Punkt steht ungefragt da', (tester) async {
      // Ohne Vorgang ist der Entwurf leer: kein Empfänger, kein Betreff.
      // Vorher erfuhr das nur, wer auf „Senden" drückte.
      await zeige(tester, breite: 900);

      expect(find.byType(VersandBereitschaftZeile), findsOneWidget);
      expect(find.textContaining('Ohne Empfänger'), findsOneWidget);
      expect(find.text('und ein weiterer'), findsOneWidget);
    });

    test('das Zahlwort hinter dem ersten Punkt wird gebeugt', () {
      expect(VersandBereitschaftZeile.weitereText(1), isNull);
      expect(VersandBereitschaftZeile.weitereText(2), 'und ein weiterer');
      expect(VersandBereitschaftZeile.weitereText(3), 'und 2 weitere');
    });
  });

  group('das Einfügeziel eines Platzhalters ist sichtbar', () {
    /// Die zwei Felder und die Platzhalterhilfe für sich — dieselben
    /// Bausteine, die Versanddialog und Vorlageneditor teilen.
    Future<PlatzhalterEinfuegeZiel> zeigeFelder(WidgetTester tester) async {
      // Hoch genug für die offene Platzhalterliste — sie ist seit dem
      // 06.09.2026 nicht mehr zugeklappt und damit rund 30 Chips lang.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(900, 1600);
      addTearDown(tester.view.reset);

      final betreff = TextEditingController();
      final text = TextEditingController();
      final ziel = PlatzhalterEinfuegeZiel(betreff: betreff, text: text);
      addTearDown(() {
        ziel.dispose();
        betreff.dispose();
        text.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  BetreffTextFelder(ziel: ziel),
                  PlatzhalterAuswahl(ziel: ziel),
                ],
              ),
            ),
          ),
        ),
      );
      return ziel;
    }

    testWidgets('ohne Zutun ist die Nachricht das Ziel, und es steht dran', (
      tester,
    ) async {
      final ziel = await zeigeFelder(tester);

      expect(
        find.text(PlatzhalterAuswahl.kopfzeile('Nachricht')),
        findsOneWidget,
      );
      expect(
        find.text(BetreffTextFelder.beschriftung('Nachricht', istZiel: true)),
        findsOneWidget,
      );

      // Auf dem Chip steht der blosse Name, eingesetzt wird er mit Klammern.
      final chip = find.widgetWithText(ActionChip, 'Referenz').first;
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();

      expect(ziel.text.text, '{{Referenz}}');
      expect(ziel.betreff.text, isEmpty);
    });

    testWidgets('ein Klick ins Betrefffeld verlegt das Ziel sichtbar', (
      tester,
    ) async {
      // Genau das war unsichtbar: Der Editor merkte sich das zuletzt
      // fokussierte Feld still, und ein Platzhalter landete im falschen.
      final ziel = await zeigeFelder(tester);

      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.focusNode == ziel.betreffFokus,
        ),
      );
      await tester.pump();

      expect(
        find.text(PlatzhalterAuswahl.kopfzeile('Betreff')),
        findsOneWidget,
      );
      expect(
        find.text(BetreffTextFelder.beschriftung('Betreff', istZiel: true)),
        findsOneWidget,
      );

      // Auf dem Chip steht der blosse Name, eingesetzt wird er mit Klammern.
      final chip = find.widgetWithText(ActionChip, 'Referenz').first;
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();

      expect(ziel.betreff.text, '{{Referenz}}');
      expect(ziel.text.text, isEmpty);
    });
  });
}
