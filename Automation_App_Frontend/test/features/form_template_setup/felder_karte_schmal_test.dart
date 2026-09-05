import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Bei `Schriftstufe.amGroessten` (Issue #57) und rund 700 px Inhaltsbreite
/// (Notebook neben einer zweiten Spalte) lief die Felderkarte an drei Stellen
/// über: die Kopfzeile mit dem „Neues Feld hinzufügen"-Knopf, der
/// Tabellenkopf (Wörter brachen mitten durch) und die Feldzeile
/// („ERFORDERLICH" überlappte den Löschen-Knopf). Ein `takeException()` deckt
/// alle drei aus derselben Karte ab.
///
/// Liefert je Slot unterschiedliche Platzhalter, damit in der Feldzeile auch
/// die Kennzeichen „beide" und „in keiner Datei" auftauchen (#35 Teil 3) —
/// nicht nur die leere Karte ohne jedes Kennzeichen.
class FestePlatzhalterJeSlot
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async {
    if (params.wordFilePath == 'ohne.docx') {
      return Right(['Versicherungsnummer', 'Mandant']);
    }
    return Right(['Versicherungsnummer']);
  }
}

/// Baut die Karte mit drei Feldern auf — Namen und Pflicht wie im
/// Fehlerscreenshot — und pumpt sie in der angegebenen Fenstergröße und
/// Schriftstufe.
Future<void> pumpeKarte(
  WidgetTester tester, {
  required Size fenstergroesse,
  required Schriftstufe schriftstufe,
}) async {
  tester.view.physicalSize = fenstergroesse;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final bloc = TemplatePlaceholdersBloc(FestePlatzhalterJeSlot())
    ..add(
      const LoadTemplatePlaceholders(
        'ohne.docx',
        TemplateFileSlot.ohneAuflistung,
      ),
    )
    ..add(
      const LoadTemplatePlaceholders(
        'mit.docx',
        TemplateFileSlot.mitAuflistung,
      ),
    );

  final formGroup = FormGroup({
    'field_0': FormControl<String>(value: 'Versicherungsnummer'),
    'field_1': FormControl<String>(value: 'Kennzeichen'),
    'field_2': FormControl<String>(value: 'Mandant'),
  });
  const fields = [
    FieldData(
      order: 0,
      label: 'field_0',
      required: true,
      inputType: InputType.text,
    ),
    FieldData(
      order: 1,
      label: 'field_1',
      required: true,
      inputType: InputType.text,
    ),
    FieldData(
      order: 2,
      label: 'field_2',
      required: false,
      inputType: InputType.text,
    ),
  ];

  await tester.pumpWidget(
    MaterialApp(
      theme: MaterialTheme(
        ThemeData.light().textTheme,
        schriftstufe: schriftstufe,
      ).light(),
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
                onReorder: (_, _) {},
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
}

void main() {
  testWidgets(
    'läuft bei größter Schrift und schmalem Fenster (700 px) nicht über',
    (tester) async {
      await pumpeKarte(
        tester,
        fenstergroesse: const Size(700, 900),
        schriftstufe: Schriftstufe.amGroessten,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Neues Feld hinzufügen'), findsOneWidget);

      // Der Tabellenkopf brach Wörter wie „BEZEICHNUNG" sonst mitten durch
      // (kein RenderFlex-Überlauf, deshalb hier gezielt geprüft statt über
      // takeException).
      final bezeichnung = tester.widget<Text>(find.text('BEZEICHNUNG'));
      expect(bezeichnung.softWrap, isFalse);
      expect(bezeichnung.overflow, TextOverflow.ellipsis);
      final anforderung = tester.widget<Text>(find.text('ANFORDERUNG'));
      expect(anforderung.softWrap, isFalse);
      expect(anforderung.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets(
    'bleibt bei normaler Schrift und breitem Fenster (1600 px) unauffällig',
    (tester) async {
      await pumpeKarte(
        tester,
        fenstergroesse: const Size(1600, 900),
        schriftstufe: Schriftstufe.normal,
      );

      expect(tester.takeException(), isNull);
      // Genug Platz: Die Beschriftung neben der Checkbox bleibt sichtbar,
      // statt vorsorglich in jeder Fensterbreite zu verschwinden.
      expect(find.text('ERFORDERLICH'), findsNWidgets(3));
    },
  );
}
