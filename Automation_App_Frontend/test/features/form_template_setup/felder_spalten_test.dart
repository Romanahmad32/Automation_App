import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/felder_spalten.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_field_item.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_table_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Kopfzeile und Feldzeile teilen sich **eine** Spaltenbeschreibung
/// ([FelderSpalten]) — der Grund, warum es die Klasse gibt.
///
/// Vorher stand die Aufteilung zweimal da, einmal im Tabellenkopf und einmal
/// in der Zeile, dazu je eigene Platzhalter für Ziehgriff und Löschen-Knopf.
/// Die beiden liefen bei jeder Änderung auseinander, und niemand merkte es,
/// bis eine Aufschrift über der falschen Spalte stand. Dieser Test misst
/// deshalb nicht die Konstanten, sondern was auf dem Bildschirm herauskommt:
/// Steht jede Zelle der Zeile unter der Zelle des Kopfes, und ist sie gleich
/// breit?
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(['Kennzeichen']);
}

void main() {
  Future<void> pumpe(WidgetTester tester, double breite) async {
    tester.view.physicalSize = Size(breite, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = TemplatePlaceholdersBloc(FestePlatzhalter())
      ..add(
        const LoadTemplatePlaceholders(
          'egal.docx',
          TemplateFileSlot.ohneAuflistung,
        ),
      );
    addTearDown(bloc.close);
    final formGroup = FormGroup({
      'field_0': FormControl<String>(value: 'Kennzeichen'),
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: ReactiveForm(
              formGroup: formGroup,
              child: Column(
                children: [
                  const TemplateFieldsTableHeader(),
                  TemplateFieldItem(
                    index: 0,
                    fieldData: const FieldData(
                      order: 0,
                      label: 'field_0',
                      required: true,
                      inputType: InputType.text,
                    ),
                    feldname: 'Kennzeichen',
                    onTypeChanged: (_) {},
                    onDatenquelleChanged: (_) {},
                    onRequiredChanged: (_) {},
                    onVorbelegungChanged: (_) {},
                    onDelete: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder zelleIn(Type behaelter, FelderSpalte spalte) => find.descendant(
    of: find.byType(behaelter),
    matching: find.byKey(spalte.zellenSchluessel),
  );

  test('jede Spalte hat entweder eine Breite oder einen Anteil', () {
    for (final spalte in FelderSpalten.alle) {
      expect(
        (spalte.breite == null) != (spalte.flex == null),
        isTrue,
        reason: spalte.schluessel,
      );
    }
  });

  testWidgets('Kopf und Zeile haben gleich viele Spalten', (tester) async {
    await pumpe(tester, 1400);

    for (final spalte in FelderSpalten.alle) {
      expect(
        zelleIn(TemplateFieldsTableHeader, spalte),
        findsOneWidget,
        reason: 'Kopf: ${spalte.schluessel}',
      );
      expect(
        zelleIn(TemplateFieldItem, spalte),
        findsOneWidget,
        reason: 'Zeile: ${spalte.schluessel}',
      );
    }
    // Und keine darüber hinaus: Beide bauen aus derselben Liste.
    expect(
      find
          .descendant(
            of: find.byType(TemplateFieldsTableHeader),
            matching: find.byType(SizedBox),
          )
          .evaluate()
          .where((e) => e.widget.key != null)
          .length,
      FelderSpalten.alle.length,
    );
  });

  for (final breite in [800.0, 1400.0]) {
    testWidgets('bei $breite px steht jede Zelle unter ihrer Aufschrift', (
      tester,
    ) async {
      await pumpe(tester, breite);

      for (final spalte in FelderSpalten.alle) {
        final kopf = zelleIn(TemplateFieldsTableHeader, spalte);
        final zeile = zelleIn(TemplateFieldItem, spalte);
        expect(
          tester.getSize(zeile).width,
          tester.getSize(kopf).width,
          reason: 'Breite ${spalte.schluessel}',
        );
        expect(
          tester.getTopLeft(zeile).dx,
          tester.getTopLeft(kopf).dx,
          reason: 'Linke Kante ${spalte.schluessel}',
        );
      }
    });
  }
}
