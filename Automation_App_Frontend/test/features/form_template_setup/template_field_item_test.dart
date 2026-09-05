import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/datums_vorbelegung_editor.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/ganzzahl_feld_klein.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_field_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die Feldzeile nach #104: eine Tabellenzeile mit gleichbleibender Höhe, und
/// alles Seltene im Aufklapper darunter.
///
/// Der Aufklapper ist der Grund für diesen Test. Vorher hing der
/// Vorbelegungs-Einsteller fest unter jeder Datumszeile; jetzt kommt und geht
/// er, und ein `StatefulWidget` mit vier `TextEditingController`n, das kommt
/// und geht, ist die Stelle, an der Eingaben verschwinden. Deshalb steht hier
/// nicht nur „klappt auf", sondern auch „was der Anwalt getippt hat, ist
/// danach noch da".
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  FestePlatzhalter(this.namen);

  final List<String> namen;

  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(namen);
}

void main() {
  /// Baut eine Zeile auf. Der Aufrufer hält den Feldstand wie die
  /// Detailseite: Was der Einsteller meldet, kommt beim nächsten Aufbau
  /// wieder herein.
  Future<void> zeigeZeile(
    WidgetTester tester, {
    required FieldData start,
    required String feldname,
    List<String> platzhalter = const ['Kennzeichen'],
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = TemplatePlaceholdersBloc(FestePlatzhalter(platzhalter))
      ..add(
        const LoadTemplatePlaceholders(
          'egal.docx',
          TemplateFileSlot.ohneAuflistung,
        ),
      );
    addTearDown(bloc.close);
    final formGroup = FormGroup({
      start.label: FormControl<String>(value: feldname),
    });
    var feld = start;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: ReactiveForm(
              formGroup: formGroup,
              child: StatefulBuilder(
                builder: (context, setState) => TemplateFieldItem(
                  index: 0,
                  fieldData: feld,
                  feldname: feldname,
                  onTypeChanged: (_) {},
                  onDatenquelleChanged: (_) {},
                  onRequiredChanged: (_) {},
                  onVorbelegungChanged: (wert) =>
                      setState(() => feld = feld.mitVorbelegung(wert)),
                  onDelete: () {},
                  onZuordnen: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Einmal für die Antwort des Anwendungsfalls, einmal für den Neuaufbau.
    await tester.pump();
    await tester.pump();
  }

  FieldData datumsfeld({FeldDatenquelle datenquelle = FeldDatenquelle.keine}) =>
      FieldData(
        order: 0,
        label: 'field_0',
        required: true,
        inputType: InputType.date,
        datenquelle: datenquelle,
      );

  /// Das Zahlenfeld hinter einer Beschriftung des Einstellers.
  Finder feldMit(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(GanzzahlFeldKlein),
    ),
    matching: find.byType(TextField),
  );

  testWidgets('zugeklappt zeigt die Zeile keinen Einsteller', (tester) async {
    // Ein Datumsfeld mit eindeutigem Namen: Es gibt etwas aufzuklappen, aber
    // nichts, das der Anwalt sehen **muss**.
    await zeigeZeile(tester, start: datumsfeld(), feldname: 'Kennzeichen');

    expect(find.byType(DatumsVorbelegungEditor), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('das Chevron holt den Einsteller eines Datumsfelds hervor', (
    tester,
  ) async {
    await zeigeZeile(tester, start: datumsfeld(), feldname: 'Kennzeichen');

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.byType(DatumsVorbelegungEditor), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets('ein mehrdeutiger Name geht offen auf', (tester) async {
    // `{{VersicherungPlzOrt}}` meint PLZ **und** Ort und bleibt deshalb
    // ungebunden. Diesen Befund muss der Anwalt beim Einrichten sehen — dass
    // er ihn hinter einem Chevron suchen müsste, wäre derselbe stille Fehler
    // wie vorher, nur eine Klickebene tiefer.
    await zeigeZeile(
      tester,
      start: const FieldData(
        order: 0,
        label: 'field_0',
        required: true,
        inputType: InputType.text,
      ),
      feldname: 'VersicherungPlzOrt',
      platzhalter: const ['VersicherungPlzOrt'],
    );

    expect(find.textContaining('PLZ und Ort'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });

  testWidgets('eine gesetzte Datenquelle lässt die Zeile zu', (tester) async {
    // Dann gewinnt die Quelle über die Erkennung, der Hinweis schweigt — und
    // eine Zeile, die sich für einen leeren Aufklapper öffnet, ist nur
    // Rauschen.
    await zeigeZeile(
      tester,
      start: const FieldData(
        order: 0,
        label: 'field_0',
        required: true,
        inputType: InputType.text,
        datenquelle: FeldDatenquelle.versichererPlz,
      ),
      feldname: 'VersicherungPlzOrt',
      platzhalter: const ['VersicherungPlzOrt'],
    );

    expect(find.textContaining('PLZ und Ort'), findsNothing);
    expect(find.byIcon(Icons.expand_less), findsNothing);
  });

  testWidgets('die Warnung „in keiner Datei" steht neben dem Namen', (
    tester,
  ) async {
    await zeigeZeile(
      tester,
      start: datumsfeld(),
      feldname: 'Zeichen',
      platzhalter: const ['Kennzeichen'],
    );

    expect(find.text('in keiner Datei'), findsOneWidget);
  });

  testWidgets('ein Feld, das ankommt, trägt keine Warnung', (tester) async {
    await zeigeZeile(
      tester,
      start: datumsfeld(),
      feldname: 'Kennzeichen',
      platzhalter: const ['Kennzeichen'],
    );

    expect(find.text('in keiner Datei'), findsNothing);
  });

  testWidgets('die Eingabe im Einsteller überlebt Zu- und Aufklappen', (
    tester,
  ) async {
    await zeigeZeile(tester, start: datumsfeld(), feldname: 'Kennzeichen');

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    await tester.enterText(feldMit('Wochen'), '3');
    await tester.pump();

    await tester.tap(find.byIcon(Icons.expand_less));
    await tester.pumpAndSettle();
    expect(find.byType(DatumsVorbelegungEditor), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    final wochen = feldMit('Wochen');
    expect(
      (wochen.evaluate().single.widget as TextField).controller!.text,
      '3',
    );
  });
}
