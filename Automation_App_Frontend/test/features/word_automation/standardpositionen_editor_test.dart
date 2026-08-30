import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:automation_app/features/word_automation/domain/repositories/standard_schadenspositionen_repository.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/standardpositionen_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/standardpositionen_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Standardpositionen-Editor in den Einstellungen (§4.4): zeigt den
/// geladenen Stand — auch wenn der Cubit beim Aufgehen schon geladen war —,
/// speichert die komplette Liste und zeigt in der Vorschau, wie die
/// Aufstellung damit startet.
class FakeStandardpositionenRepository
    implements StandardSchadenspositionenRepository {
  FakeStandardpositionenRepository(this.bestand);

  List<StandardSchadensposition> bestand;
  List<StandardSchadensposition>? zuletztGespeichert;

  @override
  Future<List<StandardSchadensposition>> lade() async => bestand;

  @override
  Future<List<StandardSchadensposition>> speichere(
    List<StandardSchadensposition> positionen,
  ) async {
    zuletztGespeichert = positionen;
    // Wie das Backend: Leerzeilen fallen weg, die leere Liste ist die Vorgabe.
    bestand = positionen.isEmpty
        ? StandardSchadenspositionen.vorgabe
        : positionen;
    return bestand;
  }
}

void main() {
  Finder bezeichnungsfeld(int zeile) => find.byType(TextField).at(zeile * 2);
  Finder betragsfeld(int zeile) => find.byType(TextField).at(zeile * 2 + 1);

  String textIn(WidgetTester tester, Finder feld) =>
      tester.widget<TextField>(feld).controller!.text;

  Future<void> zeigeEditor(
    WidgetTester tester,
    FakeStandardpositionenRepository repository, {
    bool vorGeladen = false,
  }) async {
    final cubit = StandardpositionenCubit(repository);
    if (vorGeladen) {
      // Der Fall aus stand_nachziehen.dart: Der Bloc steht beim Mounten schon
      // auf „geladen" — ein blosser Listener sähe diesen Zustand nie.
      await cubit.laden();
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit..laden(),
            child: const SingleChildScrollView(
              child: StandardpositionenEditor(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const mietwagen = StandardSchadensposition(
    bezeichnung: 'Mietwagenkosten',
    betrag: 412.5,
  );

  testWidgets('zeigt den geladenen Stand samt vorbelegtem Betrag', (
    tester,
  ) async {
    await zeigeEditor(tester, FakeStandardpositionenRepository([mietwagen]));

    expect(textIn(tester, bezeichnungsfeld(0)), 'Mietwagenkosten');
    expect(textIn(tester, betragsfeld(0)), '412,5');
  });

  testWidgets('war der Bloc schon geladen, stehen die Felder trotzdem da', (
    tester,
  ) async {
    await zeigeEditor(
      tester,
      FakeStandardpositionenRepository([mietwagen]),
      vorGeladen: true,
    );

    expect(textIn(tester, bezeichnungsfeld(0)), 'Mietwagenkosten');
  });

  testWidgets('Speichern übergibt die Zeilen mit geparstem Betrag', (
    tester,
  ) async {
    final repository = FakeStandardpositionenRepository([mietwagen]);
    await zeigeEditor(tester, repository);

    await tester.enterText(betragsfeld(0), '1.250,75');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(repository.zuletztGespeichert, const [
      StandardSchadensposition(bezeichnung: 'Mietwagenkosten', betrag: 1250.75),
    ]);
    expect(find.text('Standardpositionen gespeichert.'), findsOneWidget);
  });

  testWidgets('die Vorschau zeigt die Zeile im Dokument-Format', (
    tester,
  ) async {
    await zeigeEditor(tester, FakeStandardpositionenRepository([mietwagen]));

    expect(find.text('Forderung in €'), findsOneWidget);
    expect(find.text('412,50'), findsOneWidget);
  });

  testWidgets('ein negativer Betrag sperrt das Speichern', (tester) async {
    final repository = FakeStandardpositionenRepository([mietwagen]);
    await zeigeEditor(tester, repository);

    await tester.enterText(betragsfeld(0), '-250');
    await tester.pumpAndSettle();

    expect(find.text('Betrag darf nicht negativ sein'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(repository.zuletztGespeichert, isNull);
  });

  /// Der Knopf füllt nur die Felder — gespeichert ist erst nach „Speichern".
  /// So bleibt ein Fehlgriff folgenlos, solange niemand speichert.
  testWidgets('Zurücksetzen füllt die Vorgabe ein, ohne zu speichern', (
    tester,
  ) async {
    final repository = FakeStandardpositionenRepository([mietwagen]);
    await zeigeEditor(tester, repository);

    await tester.tap(find.text('Auf die üblichen fünf zurücksetzen'));
    await tester.pumpAndSettle();

    expect(
      textIn(tester, bezeichnungsfeld(0)),
      StandardSchadenspositionen.bezeichnungen.first,
    );
    expect(repository.zuletztGespeichert, isNull);
  });
}
