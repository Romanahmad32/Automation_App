import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/platzhalter_abschnitt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Chips sind seit #104 Stufe 3a ein **zugeklappter** Abschnitt.
///
/// Der Grund steht im Widget: In der 400 px schmalen linken Spalte des
/// zweispaltigen Editors standen je Datei zwei Dutzend Chips über der
/// Stand-Karte — also über allem, was eine Aufgabe ist. Zugeklappt bleibt
/// genau eine Zeile übrig, und die muss über **beide** Dateien zusammen
/// rechnen und jeden Namen einmal zählen: Dieselbe Regel wie in
/// `VorlagenStand` (siehe `FALLSTRICKE.md`), weil `{{Kennzeichen}}` in beiden
/// Dateien ein Platzhalter ist und nicht zwei.
///
/// Von Hand geschriebener Fake wie in den Nachbardateien — dieser Testordner
/// kennt keine Mock-Bibliothek.
class PlatzhalterJeDatei
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async {
    if (params.wordFilePath == 'ohne.docx') {
      return Right(const ['Kennzeichen', 'Mandant']);
    }
    return Right(const ['Kennzeichen', 'Schadensaufstellung']);
  }
}

void main() {
  const aufschrift = 'Platzhalter je Datei anzeigen';

  /// Baut den Abschnitt mit [dateien] verknüpften Word-Dateien auf.
  Future<List<String>> zeige(
    WidgetTester tester, {
    required List<TemplateFileSlot> dateien,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = TemplatePlaceholdersBloc(PlatzhalterJeDatei());
    addTearDown(bloc.close);
    for (final slot in dateien) {
      bloc.add(
        LoadTemplatePlaceholders(
          slot == TemplateFileSlot.ohneAuflistung ? 'ohne.docx' : 'mit.docx',
          slot,
        ),
      );
    }

    final uebernommen = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: SingleChildScrollView(
              child: PlatzhalterAbschnitt(
                onPlaceholderSelected: uebernommen.add,
                vorhandeneNamen: const ['Mandant'],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return uebernommen;
  }

  testWidgets('zugeklappt steht nur die Zählzeile da', (tester) async {
    await zeige(tester, dateien: TemplateFileSlot.values);

    // Drei verschiedene Namen in zwei Dateien: `{{Kennzeichen}}` steht in
    // beiden und zählt trotzdem einmal.
    expect(find.text('3 Platzhalter in 2 Dateien'), findsOneWidget);
    expect(find.text(aufschrift), findsOneWidget);
    expect(find.text('{{Kennzeichen}}'), findsNothing);
    expect(find.text('{{Mandant}}'), findsNothing);
  });

  testWidgets('aufgeklappt stehen die Chips je Datei da', (tester) async {
    await zeige(tester, dateien: TemplateFileSlot.values);

    await tester.tap(find.text(aufschrift));
    await tester.pumpAndSettle();

    // Je Datei eine Liste, mit ihrer eigenen Aufschrift darüber.
    expect(find.text('Ohne Auflistung (HGn)'), findsOneWidget);
    expect(find.text('Mit Auflistung'), findsOneWidget);
    // `{{Kennzeichen}}` steht in beiden Dateien — als Chip also zweimal, denn
    // der Chip ist der Weg zu genau diesem Vorkommen.
    expect(find.text('{{Kennzeichen}}'), findsNWidgets(2));
    expect(find.text('{{Mandant}}'), findsOneWidget);
  });

  testWidgets('ein offener Chip führt weiterhin zur Übernahme', (tester) async {
    final uebernommen = await zeige(tester, dateien: TemplateFileSlot.values);

    await tester.tap(find.text(aufschrift));
    await tester.pumpAndSettle();
    await tester.tap(find.text('{{Kennzeichen}}').first);

    // „Mandant" ist als Feldname schon vergeben und deshalb nicht klickbar,
    // „Kennzeichen" ist offen.
    expect(uebernommen, ['Kennzeichen']);
  });

  testWidgets('eine einzelne Datei wird auch als eine gezählt', (tester) async {
    await zeige(tester, dateien: const [TemplateFileSlot.ohneAuflistung]);

    expect(find.text('2 Platzhalter in 1 Datei'), findsOneWidget);
  });

  testWidgets('ohne verknüpfte Datei steht der Abschnitt gar nicht da', (
    tester,
  ) async {
    // Ein Aufklapper, hinter dem nichts liegt, ist eine Enttäuschung — und er
    // nähme der Stand-Karte darüber Aufmerksamkeit weg.
    await zeige(tester, dateien: const []);

    expect(find.text(aufschrift), findsNothing);
  });
}
