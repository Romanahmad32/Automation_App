import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/domain/services/gespeicherter_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/delete_form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/vorlagen_kopie_cubit/vorlagen_kopie_cubit.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/form_template_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Übersichtszeile (#104 Stufe 4): Sie trägt jetzt das Kennzeichen
/// „unvollständig" und die Zeilenaktion „Duplizieren".
///
/// Der Name der Kopie entsteht aus dem **geladenen Bestand** — die Zeile
/// nimmt ihn aus dem `FormTemplateOverviewBloc` und reicht ihn weiter, statt
/// den Cubit an einen zweiten Bloc zu hängen.

class FesteVorlagen implements UseCase<List<FormTemplate>, NoParams> {
  FesteVorlagen(this.vorlagen);

  final List<FormTemplate> vorlagen;

  @override
  Future<Either<Failure, List<FormTemplate>>> call(NoParams params) async =>
      Right(vorlagen);
}

class StillesLoeschen implements UseCase<void, DeleteFormTemplateParams> {
  @override
  Future<Either<Failure, void>> call(DeleteFormTemplateParams params) async =>
      Right(null);
}

class MerkendesErstellen implements UseCase<void, CreateFormTemplateRequest> {
  CreateFormTemplateRequest? letzteAnfrage;

  @override
  Future<Either<Failure, void>> call(CreateFormTemplateRequest params) async {
    letzteAnfrage = params;
    return Right(null);
  }
}

void main() {
  const felder = [
    FieldData(
      order: 0,
      label: 'Kennzeichen',
      required: true,
      inputType: InputType.text,
    ),
  ];

  FormTemplate vorlage({
    int id = 1,
    String name = 'Anspruchsschreiben',
    GespeicherterStand? stand,
  }) => FormTemplate(
    id: id,
    templateName: name,
    fields: felder,
    wordFilePathOhneAuflistung: 'ohne.docx',
    stand: stand,
  );

  /// Baut die Zeile mit dem Bestand, den die Übersicht geladen hat.
  Future<MerkendesErstellen> pumpeZeile(
    WidgetTester tester, {
    required FormTemplate zeile,
    required List<FormTemplate> bestand,
  }) async {
    final erstellen = MerkendesErstellen();
    final uebersicht = FormTemplateOverviewBloc(
      FesteVorlagen(bestand),
      StillesLoeschen(),
    )..add(LoadFormTemplatesEvent());
    addTearDown(uebersicht.close);
    final kopie = VorlagenKopieCubit(erstellen);
    addTearDown(kopie.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: uebersicht),
              BlocProvider.value(value: kopie),
            ],
            child: FormTemplateRow(template: zeile),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return erstellen;
  }

  testWidgets(
    'zeigt „Noch nicht geprüft", solange kein Stand gespeichert ist',
    (tester) async {
      final ohneStand = vorlage();
      await pumpeZeile(tester, zeile: ohneStand, bestand: [ohneStand]);

      expect(find.text('Noch nicht geprüft'), findsOneWidget);
    },
  );

  testWidgets('zeigt den gespeicherten Mangel samt Zahl', (tester) async {
    final unvollstaendig = vorlage(
      stand: const GespeicherterStand(
        vollstaendig: false,
        offen: 4,
        warnungen: false,
      ),
    );
    await pumpeZeile(tester, zeile: unvollstaendig, bestand: [unvollstaendig]);

    expect(find.text('Unvollständig · 4 offen'), findsOneWidget);
  });

  testWidgets('dupliziert über die Zeilenaktion, ohne die Word-Dateien', (
    tester,
  ) async {
    final original = vorlage();
    final erstellen = await pumpeZeile(
      tester,
      zeile: original,
      bestand: [original],
    );

    await tester.tap(find.byTooltip('Duplizieren'));
    await tester.pumpAndSettle();

    final anfrage = erstellen.letzteAnfrage;
    expect(anfrage, isNotNull);
    expect(anfrage!.templateName, 'Anspruchsschreiben (Kopie)');
    expect(anfrage.wordFilePathOhneAuflistung, isNull);
    expect(anfrage.wordFilePathMitAuflistung, isNull);
  });

  testWidgets('weicht Namen aus, die im geladenen Bestand schon stehen', (
    tester,
  ) async {
    final original = vorlage();
    final erstellen = await pumpeZeile(
      tester,
      zeile: original,
      bestand: [
        original,
        vorlage(id: 2, name: 'Anspruchsschreiben (Kopie)'),
      ],
    );

    await tester.tap(find.byTooltip('Duplizieren'));
    await tester.pumpAndSettle();

    expect(
      erstellen.letzteAnfrage!.templateName,
      'Anspruchsschreiben (Kopie 2)',
    );
  });
}
