import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';

import '../vorgang_starten/vorgang_starten_doubles.dart';

/// Der Dienst, der die Vorlage speichert. Zwei Wege des Wizards kommen hier an:
/// [WizardCubit.linkWordFileToTemplate] und [WizardCubit.aktualisiereFeld].
///
/// [gespeicherte] hält fest, was hinausging — und antwortet mit genau dem, was
/// hereinkam, wie der Dienst es auch tut.
class FakeUpdateFormTemplate
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  final List<FormTemplate> gespeicherte = [];

  /// Auf `true` gesetzt, schlägt jedes Speichern fehl. Dann darf am Wizard
  /// nichts hängenbleiben, was der Bestand nicht trägt.
  bool schlaegtFehl = false;

  @override
  Future<Either<Failure, FormTemplate>> call(
    UpdateFormTemplateParams params,
  ) async {
    gespeicherte.add(params.formTemplate);
    return schlaegtFehl
        ? Left(ServerFailure(message: 'Dienst nicht erreichbar'))
        : Right(params.formTemplate);
  }
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
/// [ablage] hält fest, was als Entwurf hinausging (`ablage.entwuerfe`),
/// [updateFormTemplate], was an Vorlagen gespeichert wurde.
class WizardUmgebung {
  final VorgangAblageDouble ablage = VorgangAblageDouble();
  final VorgangPersistenzFehlerCubit fehler = VorgangPersistenzFehlerCubit();
  final FakeUpdateFormTemplate updateFormTemplate = FakeUpdateFormTemplate();
  final FakeGetMandanten getMandanten;

  late final VorgangCubit vorgaenge = VorgangCubit(ablage, fehler);
  late final WizardCubit wizard = WizardCubit(
    updateFormTemplate,
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
