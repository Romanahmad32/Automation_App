import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';

import '../vorgang_starten/vorgang_starten_doubles.dart';

/// Die Vorlage speichert nur [WizardCubit.linkWordFileToTemplate] — wer das
/// nicht prüft, kommt hier nie an.
class FakeUpdateFormTemplate
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  @override
  Future<Either<Failure, FormTemplate>> call(UpdateFormTemplateParams params) =>
      throw UnimplementedError();
}

/// Das Mandantenregister, aus dem `selectVorgang` den verknüpften Mandanten
/// nachlädt. [aufrufe] zeigt, ob überhaupt geladen wurde.
class FakeGetMandanten implements UseCase<List<Mandant>, NoParams> {
  final List<Mandant> mandanten;
  int aufrufe = 0;

  FakeGetMandanten([this.mandanten = const []]);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async {
    aufrufe++;
    return Right(mandanten);
  }
}

/// Ein [WizardCubit] mit allem, was er braucht — samt der Ablage, in die sein
/// Entwurf geht. Seit der Entwurf am Vorgang liegt, hängt der Wizard am
/// app-weiten [VorgangCubit]; ihn in jeder Testdatei neu zusammenzusetzen
/// hieße, dieselben vier Zeilen viermal zu pflegen.
///
/// [ablage] hält fest, was als Entwurf hinausging (`ablage.entwuerfe`).
class WizardUmgebung {
  final VorgangAblageDouble ablage = VorgangAblageDouble();
  final VorgangPersistenzFehlerCubit fehler = VorgangPersistenzFehlerCubit();
  final FakeGetMandanten getMandanten;

  late final VorgangCubit vorgaenge = VorgangCubit(ablage, fehler);
  late final WizardCubit wizard = WizardCubit(
    FakeUpdateFormTemplate(),
    getMandanten,
    vorgaenge,
  );

  WizardUmgebung({List<Mandant> mandanten = const []})
    : getMandanten = FakeGetMandanten(mandanten);

  /// Alle drei Cubits schließen. Ohne das bleiben StreamController offen, und
  /// ein Timer des Wizards schlägt in einem *anderen* Test als „A Timer is
  /// still pending" auf.
  Future<void> schliesse() async {
    await wizard.close();
    await vorgaenge.close();
    await fehler.close();
  }
}
