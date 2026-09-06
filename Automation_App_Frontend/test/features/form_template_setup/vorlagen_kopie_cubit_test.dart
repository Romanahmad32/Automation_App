import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/vorlagen_kopie_cubit/vorlagen_kopie_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Duplizieren einer Vorlage (#104 Stufe 4). Es läuft über den vorhandenen
/// Anlege-Weg (`CreateFormTemplate`) — kein eigener Endpunkt, keine zweite
/// Schreibstelle.
///
/// Ein **eigener** Cubit und nicht der `FormTemplateOverviewBloc`: Der ist ein
/// `@lazySingleton`, den sich die Vorlagenverwaltung mit dem Wizard-Dropdown in
/// „Word Automation" teilt. Ein Namenskonflikt (409) beim Duplizieren würde
/// dort als `FormTemplateOverviewError` einschlagen und die Vorlagenliste des
/// Wizards durch eine Fehlermeldung ersetzen.

/// Merkt sich die Anfrage, statt sie zu verschicken — wie
/// `MerkendesErstellen` in `datums_vorbelegung_speicherweg_test.dart`; dieser
/// Testordner kennt keine Mock-Bibliothek.
class MerkendesErstellen implements UseCase<void, CreateFormTemplateRequest> {
  CreateFormTemplateRequest? letzteAnfrage;

  @override
  Future<Either<Failure, void>> call(CreateFormTemplateRequest params) async {
    letzteAnfrage = params;
    return Right(null);
  }
}

/// Antwortet wie der Dienst auf einen Namenskonflikt: 409 → `LocalFailure` mit
/// der Meldung des Backends (siehe `ApiFormTemplateDatasource._mapError`).
class ScheiterndesErstellen
    implements UseCase<void, CreateFormTemplateRequest> {
  @override
  Future<Either<Failure, void>> call(CreateFormTemplateRequest params) async =>
      Left(
        LocalFailure(
          message:
              'FormTemplateException: Vorlage mit Name '
              '${params.templateName} existiert bereits',
        ),
      );
}

void main() {
  const felder = [
    FieldData(
      order: 0,
      label: 'Kennzeichen',
      required: true,
      inputType: InputType.text,
      datenquelle: FeldDatenquelle.kennzeichenGegner,
    ),
    FieldData(
      order: 1,
      label: 'Zahlungsfrist',
      required: false,
      inputType: InputType.date,
      vorbelegung: DatumsVorbelegung(wochen: 5),
    ),
  ];

  const original = FormTemplate(
    id: 7,
    templateName: 'Anspruchsschreiben',
    fields: felder,
    wordFilePathOhneAuflistung: r'C:\Vorlagen\HGN.docx',
    wordFilePathMitAuflistung: r'C:\Vorlagen\HGN mit Auflistung.docx',
  );

  test(
    'legt die Kopie über den Anlege-Weg an, mit allen Feldangaben',
    () async {
      final erstellen = MerkendesErstellen();
      final cubit = VorlagenKopieCubit(erstellen);
      addTearDown(cubit.close);

      await cubit.dupliziere(
        original,
        vorhandeneNamen: const ['Anspruchsschreiben'],
      );

      final anfrage = erstellen.letzteAnfrage;
      expect(anfrage, isNotNull);
      expect(anfrage!.templateName, 'Anspruchsschreiben (Kopie)');
      expect(anfrage.fields.length, 2);
      expect(anfrage.fields[0].label, 'Kennzeichen');
      expect(anfrage.fields[0].required, isTrue);
      expect(anfrage.fields[0].datenquelle, FeldDatenquelle.kennzeichenGegner);
      expect(anfrage.fields[1].label, 'Zahlungsfrist');
      expect(anfrage.fields[1].inputType, InputType.date);
      expect(anfrage.fields[1].vorbelegung, const DatumsVorbelegung(wochen: 5));
    },
  );

  test('die Kopie startet ohne Word-Dateien und sagt das im Stand', () async {
    final erstellen = MerkendesErstellen();
    final cubit = VorlagenKopieCubit(erstellen);
    addTearDown(cubit.close);

    await cubit.dupliziere(original, vorhandeneNamen: const []);

    final anfrage = erstellen.letzteAnfrage!;
    expect(anfrage.wordFilePathOhneAuflistung, isNull);
    expect(anfrage.wordFilePathMitAuflistung, isNull);
    // Ohne Datei sind keine Platzhalter bekannt: unvollständig, aber ohne Zahl.
    expect(anfrage.stand?.vollstaendig, isFalse);
    expect(anfrage.stand?.offen, 0);
  });

  test('weicht einem belegten Namen aus', () async {
    final erstellen = MerkendesErstellen();
    final cubit = VorlagenKopieCubit(erstellen);
    addTearDown(cubit.close);

    await cubit.dupliziere(
      original,
      vorhandeneNamen: const [
        'Anspruchsschreiben',
        'Anspruchsschreiben (Kopie)',
      ],
    );

    expect(
      erstellen.letzteAnfrage!.templateName,
      'Anspruchsschreiben (Kopie 2)',
    );
  });

  test('meldet Erfolg mit dem Namen und geht zurück in den Ruhezustand', () {
    final cubit = VorlagenKopieCubit(MerkendesErstellen());
    addTearDown(cubit.close);

    expectLater(
      cubit.stream,
      emitsInOrder([
        isA<VorlagenKopieLaeuft>(),
        isA<VorlagenKopieErfolg>().having(
          (zustand) => zustand.name,
          'name',
          'Anspruchsschreiben (Kopie)',
        ),
        isA<VorlagenKopieRuht>(),
      ]),
    );

    return cubit.dupliziere(original, vorhandeneNamen: const []);
  });

  test('ein Namenskonflikt (409) kommt als Meldung an, nicht als Absturz', () {
    final cubit = VorlagenKopieCubit(ScheiterndesErstellen());
    addTearDown(cubit.close);

    expectLater(
      cubit.stream,
      emitsInOrder([
        isA<VorlagenKopieLaeuft>(),
        isA<VorlagenKopieFehler>().having(
          (zustand) => zustand.meldung,
          'meldung',
          contains('existiert bereits'),
        ),
        isA<VorlagenKopieRuht>(),
      ]),
    );

    return cubit.dupliziere(original, vorhandeneNamen: const []);
  });
}
