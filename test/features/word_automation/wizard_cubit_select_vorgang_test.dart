import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUpdateFormTemplate
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  @override
  Future<Either<Failure, FormTemplate>> call(UpdateFormTemplateParams params) =>
      throw UnimplementedError();
}

class _FakeGetMandanten implements UseCase<List<Mandant>, NoParams> {
  final List<Mandant> mandanten;
  int aufrufe = 0;

  _FakeGetMandanten(this.mandanten);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async {
    aufrufe++;
    return Right(mandanten);
  }
}

void main() {
  final mandant = Mandant(
    id: 7,
    vorname: 'Erika',
    nachname: 'Mustermann',
    erstelltAm: DateTime(2026, 1, 1),
  );

  Vorgang vorgang({int? mandantId}) => Vorgang.ausAnfrage(
    referenz: '84/26 C03_GG-CK 321',
    angefragtAm: DateTime(2026, 4, 8),
    mandantId: mandantId,
    mandantName: 'Erika Mustermann',
  );

  test('selectVorgang löst den verknüpften Mandanten auf', () async {
    final getMandanten = _FakeGetMandanten([mandant]);
    final cubit = WizardCubit(_FakeUpdateFormTemplate(), getMandanten);

    await cubit.selectVorgang(vorgang(mandantId: 7));

    expect(cubit.state.selectedVorgang?.referenz, '84/26 C03_GG-CK 321');
    expect(cubit.state.selectedMandant, mandant);
    await cubit.close();
  });

  test('selectVorgang ohne mandantId lädt das Register nicht', () async {
    final getMandanten = _FakeGetMandanten([mandant]);
    final cubit = WizardCubit(_FakeUpdateFormTemplate(), getMandanten);

    await cubit.selectVorgang(vorgang());

    expect(cubit.state.selectedVorgang, isNotNull);
    expect(cubit.state.selectedMandant, isNull);
    expect(getMandanten.aufrufe, 0);
    await cubit.close();
  });

  test('selectVorgang(null) hebt die Auswahl auf', () async {
    final getMandanten = _FakeGetMandanten([mandant]);
    final cubit = WizardCubit(_FakeUpdateFormTemplate(), getMandanten);

    await cubit.selectVorgang(vorgang(mandantId: 7));
    await cubit.selectVorgang(null);

    expect(cubit.state.selectedVorgang, isNull);
    expect(cubit.state.selectedMandant, isNull);
    await cubit.close();
  });
}
