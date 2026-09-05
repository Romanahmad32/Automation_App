import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/felder_spalten.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/template_fields_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Der Überlaufwächter der Felderkarte (Issue #57): Bei
/// `Schriftstufe.amGroessten` und rund 700 px Inhaltsbreite (Notebook neben
/// einer zweiten Spalte) lief sie an drei Stellen über — Kartenkopf,
/// Tabellenkopf und Feldzeile.
///
/// Mit der neuen Feldzeile (#104) prüft er dieselbe Eigenschaft an anderer
/// Gestalt. Die alten Erwartungen benannten die Kopfzeile Wort für Wort
/// („BEZEICHNUNG" bricht nicht um, „ERFORDERLICH" steht dreimal) — beides gibt
/// es nicht mehr: Die Aufschriften kommen jetzt aus [FelderSpalten], und die
/// Pflichtspalte trägt nur noch eine Checkbox, weil ihre Überschrift im
/// Tabellenkopf steht statt achtzehnmal in den Zeilen. Der Wächter liest die
/// Aufschriften deshalb aus [FelderSpalten] und hält nicht länger Literale
/// nach; was er sichert, ist unverändert: **kein Überlauf** bei 700 px und
/// größter Schrift, und bei 1600 px steht jede Aufschrift ungekürzt da.
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
///
/// Der Stand ist vollständig: Dann steht der Filter auf „Alle", alle drei
/// Zeilen sind zu sehen, und die Auswahl im Kartenkopf ist trotzdem da. Ein
/// Feld („Kennzeichen") kommt in keiner Datei vor und trägt deshalb die
/// Warnung neben dem Namen — genau der Fall, der die breiteste Spalte
/// zusätzlich belastet.
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
  addTearDown(bloc.close);

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
  final stand = VorlagenStand.bestimme(
    hatDateiOhne: true,
    hatDateiMit: true,
    platzhalterOhne: const ['Versicherungsnummer', 'Mandant'],
    platzhalterMit: const ['Versicherungsnummer'],
    feldnamen: const ['Versicherungsnummer', 'Kennzeichen', 'Mandant'],
  );

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

/// Die Aufschriften des Tabellenkopfs — aus der Spaltenbeschreibung, nicht aus
/// einer zweiten Liste hier.
Iterable<String> aufschriften() => FelderSpalten.alle
    .map((spalte) => spalte.beschriftung)
    .where((text) => text.isNotEmpty);

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
      // Die Karte zeigt dabei wirklich alles, was Platz braucht: drei Zeilen,
      // eine davon mit Warnung, dazu Filter und ⋯-Menü im Kopf.
      expect(find.text('Felder (3)'), findsOneWidget);
      expect(find.text('in keiner Datei'), findsOneWidget);
      for (final text in aufschriften()) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
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
      // Genug Platz: Jede Aufschrift steht ungekürzt da, statt vorsorglich in
      // jeder Fensterbreite mit Auslassung abgeschnitten zu werden.
      for (final text in aufschriften()) {
        final absatz = tester.renderObject<RenderParagraph>(find.text(text));
        expect(absatz.didExceedMaxLines, isFalse, reason: text);
      }
    },
  );
}
