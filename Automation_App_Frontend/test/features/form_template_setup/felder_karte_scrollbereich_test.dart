import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/felder_karte_kopf.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_field_item.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_table_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der eigene Scrollbereich der Felderkarte (#104 Stufe 3a).
///
/// Zwei Zusagen hängen daran, und beide gibt es nur zusammen: Kartenkopf und
/// Tabellenkopf bleiben beim Scrollen **stehen** — sonst scrollte der Filter,
/// den der Anwalt gerade umstellen will, aus dem Bild —, und die Liste ist
/// **wirklich** virtualisiert. Eine `ReorderableListView` mit `shrinkWrap` in
/// einem Scrollbereich sieht aus wie eine Liste, die scrollt, baut aber jede
/// Zeile: bei achtzehn Feldern achtzehn Dropdowns, achtzehn Textfelder und
/// achtzehn Aufklapper, jedes Mal neu.
///
/// Die gestapelte Fassung ist der Gegenbeweis dazu und steht deshalb im selben
/// Test: Dort **muss** `shrinkWrap` an bleiben, weil die Seite den
/// Scrollbereich trägt.
class FestePlatzhalter
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  @override
  Future<Either<Failure, List<String>>> call(
    GetTemplatePlaceholdersParams params,
  ) async => Right(const []);
}

void main() {
  const anzahl = 30;

  /// Vollständig und ohne offene Punkte: Dann steht der Filter auf „Alle" und
  /// alle dreissig Zeilen sind sichtbar — nur so sagt die Zählung unten etwas
  /// über die Virtualisierung und nicht über den Filter.
  const stand = VorlagenStand(
    platzhalterOhneFeld: [],
    felderOhneVorkommen: [],
    hatDateiOhne: true,
    hatDateiMit: false,
    platzhalterUnbekannt: false,
  );

  Future<void> zeigeKarte(
    WidgetTester tester, {
    required bool eigenerScrollbereich,
  }) async {
    // Breit genug für die Feldzeile, hoch genug für einen echten Bildlauf und
    // zu niedrig für dreissig Zeilen.
    tester.view.physicalSize = const Size(1600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = TemplatePlaceholdersBloc(FestePlatzhalter());
    addTearDown(bloc.close);

    final formGroup = FormGroup({
      for (var i = 0; i < anzahl; i++)
        'field_$i': FormControl<String>(value: 'Feld $i'),
    });
    final fields = [
      for (var i = 0; i < anzahl; i++)
        FieldData(
          order: i,
          label: 'field_$i',
          required: false,
          inputType: InputType.text,
        ),
    ];

    final karte = TemplateFieldsCard(
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
      eigenerScrollbereich: eigenerScrollbereich,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: ReactiveForm(
              formGroup: formGroup,
              // Zweispaltig hängt die Karte in einem `Expanded` und bekommt
              // damit eine begrenzte Höhe; gestapelt trägt die Seite den
              // Scrollbereich. Genau diese beiden Umgebungen baut das Layout.
              child: eigenerScrollbereich
                  ? Column(children: [Expanded(child: karte)])
                  : SingleChildScrollView(child: karte),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  int gebauteZeilen(WidgetTester tester) => tester
      .widgetList<TemplateFieldItem>(find.byType(TemplateFieldItem))
      .length;

  Finder zeile(int index) => find.byWidgetPredicate(
    (widget) =>
        widget is TemplateFieldItem && widget.fieldData.label == 'field_$index',
  );

  testWidgets('mit eigenem Scrollbereich baut die Liste nicht alle 30 Zeilen', (
    tester,
  ) async {
    await zeigeKarte(tester, eigenerScrollbereich: true);

    expect(tester.takeException(), isNull);
    expect(gebauteZeilen(tester), lessThan(anzahl));
    expect(gebauteZeilen(tester), greaterThan(0));
  });

  testWidgets('beim Scrollen bleiben Kartenkopf und Tabellenkopf stehen', (
    tester,
  ) async {
    await zeigeKarte(tester, eigenerScrollbereich: true);

    final kartenkopfVorher = tester.getTopLeft(find.byType(FelderKarteKopf));
    final tabellenkopfVorher = tester.getTopLeft(
      find.byType(TemplateFieldsTableHeader),
    );
    expect(zeile(0), findsOneWidget);

    await tester.drag(find.byType(ReorderableListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    // Die Liste hat sich wirklich bewegt …
    expect(zeile(0), findsNothing);
    // … und die beiden Köpfe stehen unverrückt an ihrer Stelle.
    expect(tester.getTopLeft(find.byType(FelderKarteKopf)), kartenkopfVorher);
    expect(
      tester.getTopLeft(find.byType(TemplateFieldsTableHeader)),
      tabellenkopfVorher,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gestapelt baut die Liste weiterhin jede Zeile', (tester) async {
    // Der Gegenbeweis: Ohne eigenen Scrollbereich trägt die Seite den Lauf,
    // und die Karte muss ihre volle Höhe kennen.
    await zeigeKarte(tester, eigenerScrollbereich: false);

    expect(tester.takeException(), isNull);
    expect(gebauteZeilen(tester), anzahl);
  });
}
