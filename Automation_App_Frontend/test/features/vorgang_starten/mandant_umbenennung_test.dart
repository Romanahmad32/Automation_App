import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_uebersicht_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Karte lässt sich einen Mandanten aus dem Register geben, man tippt einen
/// **anderen Namen** darüber und speichert — und benennt damit den bestehenden
/// Registereintrag um. Alle Vorgänge, die an ihm hängen, tragen danach den
/// neuen Namen; den Menschen, der vorher so hieß, gibt es nicht mehr (#50).
///
/// Das Verhalten bleibt gewollt: Ein Tippfehler im Namen soll sich hier
/// korrigieren lassen, ohne dass jemand in den Mandanten-Tab wechselt. Was
/// fehlte, war die Ansage. Die Rückfrage sagte „Mandantendaten aktualisieren"
/// und zeigte den Namen als eine Zeile unter sieben — dieselbe Aufmachung wie
/// bei einer geänderten Hausnummer.
///
/// Geprüft wird deshalb beides: dass die Umbenennung sich in Titel, Warnung und
/// Knopfbeschriftung zeigt — und dass die gewöhnliche Aktualisierung davon
/// verschont bleibt. Eine Warnung, die immer dasteht, warnt vor nichts mehr.
void main() {
  Future<void> zeigeDialog(
    WidgetTester tester, {
    MandantUmbenennung? umbenennung,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MandantUebersichtDialog(
            istNeu: false,
            umbenennung: umbenennung,
            zeilen: const [
              MandantFeldDiff(
                label: 'Name',
                alt: 'Max Müller',
                neu: 'Erika Mustermann',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Der Text der Warnfläche am Stück — sie steht in einem einzigen `Text`,
  /// damit der Satz umbrechen darf, wo der Platz es verlangt.
  String? warntext(WidgetTester tester) {
    final treffer = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.data?.contains('wird umbenannt') ?? false);
    return treffer.isEmpty ? null : treffer.first.data;
  }

  const dreiVorgaenge = MandantUmbenennung(
    alt: 'Max Müller',
    neu: 'Erika Mustermann',
    betroffeneVorgaenge: 3,
  );

  testWidgets('eine Umbenennung heißt im Dialog auch so', (tester) async {
    await zeigeDialog(tester, umbenennung: dreiVorgaenge);

    expect(find.text('Mandanten umbenennen'), findsOneWidget);
    expect(find.text('Mandantendaten aktualisieren'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Umbenennen'),
      findsOneWidget,
      reason:
          'Der Knopf muss sagen, was er tut — „Aktualisieren" tut es nicht.',
    );
    expect(warntext(tester), contains('„Max Müller"'));
    expect(warntext(tester), contains('„Erika Mustermann"'));
  });

  testWidgets('die Warnung nennt die Zahl der betroffenen Vorgänge', (
    tester,
  ) async {
    await zeigeDialog(tester, umbenennung: dreiVorgaenge);

    expect(warntext(tester), contains('Alle 3 Vorgänge'));
  });

  testWidgets('ein einzelner Vorgang wird nicht in den Plural gezwungen', (
    tester,
  ) async {
    await zeigeDialog(
      tester,
      umbenennung: const MandantUmbenennung(
        alt: 'Max Müller',
        neu: 'Erika Mustermann',
        betroffeneVorgaenge: 1,
      ),
    );

    expect(warntext(tester), contains('Der eine Vorgang'));
  });

  /// Hängt noch kein Vorgang am Eintrag, ist die Umbenennung folgenlos. Die
  /// Warnung bleibt — der Eintrag verliert trotzdem seinen Namen —, aber sie
  /// behauptet keine Folgen, die es nicht gibt.
  testWidgets('ohne Vorgänge am Eintrag steht keine Zahl in der Warnung', (
    tester,
  ) async {
    await zeigeDialog(
      tester,
      umbenennung: const MandantUmbenennung(
        alt: 'Max Müller',
        neu: 'Erika Mustermann',
      ),
    );

    expect(warntext(tester), isNotNull);
    expect(warntext(tester), isNot(contains('Vorgänge, die daran hängen')));
    expect(warntext(tester), isNot(contains('Der eine Vorgang')));
  });

  testWidgets('die gewöhnliche Aktualisierung bleibt ohne Warnung', (
    tester,
  ) async {
    await zeigeDialog(tester);

    expect(find.text('Mandantendaten aktualisieren'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Aktualisieren'), findsOneWidget);
    expect(warntext(tester), isNull);
  });
}
