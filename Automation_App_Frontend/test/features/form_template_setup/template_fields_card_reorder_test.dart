import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Beim Ziehen hebt die ReorderableListView die Zeile in ein Overlay
/// **außerhalb** von ReactiveForm und Bloc-Providern der Seite. Der
/// proxyDecorator muss beides neu umschließen — ohne den Bloc warf das
/// FeldVorkommenBadge in der gezogenen Zeile eine ProviderNotFoundException.
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(['Kennzeichen', 'Frist']);
}

void main() {
  testWidgets('das Ziehen einer Feldzeile wirft keine Ausnahme und sortiert '
      'um', (tester) async {
    // Die Feldzeile ist für die 800-px-Standardfläche des Testers zu breit.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = TemplatePlaceholdersBloc(FestePlatzhalter())
      ..add(
        const LoadTemplatePlaceholders(
          'egal.docx',
          TemplateFileSlot.ohneAuflistung,
        ),
      );
    final formGroup = FormGroup({
      'field_0': FormControl<String>(value: 'Kennzeichen'),
      'field_1': FormControl<String>(value: 'Frist'),
    });
    final fields = [
      const FieldData(
        order: 0,
        label: 'field_0',
        required: true,
        inputType: InputType.text,
      ),
      const FieldData(
        order: 1,
        label: 'field_1',
        required: true,
        inputType: InputType.text,
      ),
    ];
    final umsortiert = <(int, int)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: ReactiveForm(
              formGroup: formGroup,
              child: SingleChildScrollView(
                child: TemplateFieldsCard(
                  fields: fields,
                  formGroup: formGroup,
                  onAddField: () {},
                  onReorder: (von, nach) => umsortiert.add((von, nach)),
                  onTypeChanged: (_, _) {},
                  onDatenquelleChanged: (_, _) {},
                  onRequiredChanged: (_, _) {},
                  onDelete: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.timedDrag(
      find.byIcon(Icons.drag_indicator).first,
      const Offset(0, 90),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(umsortiert, isNotEmpty);
  });
}
