import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_field_item.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der Filter über der Feldertabelle (#104) — hier an der Karte, nicht an der
/// Rechnung (die steht in `felder_filter_test.dart`).
///
/// Was diese Karte leisten muss und die Rechnung allein nicht zeigt: Sie geht
/// bei einer unvollständigen Vorlage schon gefiltert auf, sie schaltet dabei
/// das Umsortieren ab (die sichtbaren Zeilen sind dann nicht mehr der
/// Feldbestand, ein Zug darin verschöbe das Feld an eine Stelle ausserhalb
/// der Ansicht), und sie sagt, wo die offenen Punkte sind, die **keine** Zeile
/// haben: Platzhalter ohne Feld.
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(['Kennzeichen', 'Fahrzeug']);
}

void main() {
  const namen = ['Kennzeichen', 'Zeichen', 'Frist'];

  /// Eine Vorlage mit einer Word-Datei: „Kennzeichen" kommt an, „Zeichen" und
  /// „Frist" nirgends, und `{{Fahrzeug}}` hat kein Feld.
  VorlagenStand standMitDatei() => VorlagenStand.bestimme(
    hatDateiOhne: true,
    hatDateiMit: false,
    platzhalterOhne: const ['Kennzeichen', 'Fahrzeug'],
    platzhalterMit: null,
    feldnamen: namen,
  );

  Future<void> zeigeKarte(
    WidgetTester tester, {
    required VorlagenStand stand,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = TemplatePlaceholdersBloc(FestePlatzhalter())
      ..add(
        const LoadTemplatePlaceholders(
          'ohne.docx',
          TemplateFileSlot.ohneAuflistung,
        ),
      );
    addTearDown(bloc.close);

    final formGroup = FormGroup({
      for (var i = 0; i < namen.length; i++)
        'field_$i': FormControl<String>(value: namen[i]),
    });
    final fields = [
      for (var i = 0; i < namen.length; i++)
        FieldData(
          order: i,
          label: 'field_$i',
          required: false,
          inputType: InputType.text,
        ),
    ];

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
                  stand: stand,
                  onAddField: () {},
                  onReorder: (_, _) {},
                  onTypeChanged: (_, _) {},
                  onDatenquelleChanged: (_, _) {},
                  onRequiredChanged: (_, _) {},
                  onDelete: (_) {},
                  feldname: (key) => formGroup.control(key).value as String?,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  List<String> sichtbareFelder(WidgetTester tester) => tester
      .widgetList<TemplateFieldItem>(find.byType(TemplateFieldItem))
      .map((zeile) => zeile.fieldData.label)
      .toList();

  testWidgets('eine unvollständige Vorlage geht auf „Nur offene" auf', (
    tester,
  ) async {
    await zeigeKarte(tester, stand: standMitDatei());

    // Zwei Felder ohne Vorkommen — und die Zahl auf dem Knopf ist drei, weil
    // `{{Fahrzeug}}` genauso offen ist.
    expect(sichtbareFelder(tester), ['field_1', 'field_2']);
    expect(find.text('Nur offene (3)'), findsOneWidget);
    expect(find.text('Zu prüfen (0)'), findsOneWidget);
  });

  testWidgets('bei aktivem Filter ist das Umsortieren aus', (tester) async {
    await zeigeKarte(tester, stand: standMitDatei());

    final zeilen = tester.widgetList<TemplateFieldItem>(
      find.byType(TemplateFieldItem),
    );
    expect(zeilen.every((zeile) => !zeile.umsortierenMoeglich), isTrue);
    expect(find.byType(ReorderableDragStartListener), findsNothing);
  });

  testWidgets('der offene Platzhalter ohne Feld bekommt seine Zeile', (
    tester,
  ) async {
    await zeigeKarte(tester, stand: standMitDatei());

    expect(
      find.text('1 Platzhalter ohne Feld — siehe Dateien/Platzhalter'),
      findsOneWidget,
    );
  });

  testWidgets('„Alle" zeigt jede Zeile und gibt den Ziehgriff frei', (
    tester,
  ) async {
    await zeigeKarte(tester, stand: standMitDatei());

    await tester.tap(find.text('Alle'));
    await tester.pumpAndSettle();

    expect(sichtbareFelder(tester), ['field_0', 'field_1', 'field_2']);
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
    expect(
      find.text('1 Platzhalter ohne Feld — siehe Dateien/Platzhalter'),
      findsNothing,
    );
  });

  testWidgets('das ⋯-Menü führt zum neuen Feld von Hand', (tester) async {
    await zeigeKarte(tester, stand: standMitDatei());

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Neues Feld von Hand'), findsOneWidget);
    expect(
      find.text('Platzhalter wird erst noch in Word ergänzt'),
      findsOneWidget,
    );
  });
}
