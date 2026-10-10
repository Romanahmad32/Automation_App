import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';

/// Die zwei Fragen, die nach jedem Vorlagenwechsel zusammen zu beantworten
/// sind: **welche Fassung** (ohne/mit Auflistung) nun gilt, und ob der Schritt,
/// auf dem der Anwalt gerade steht, es danach überhaupt noch gibt.
///
/// Sie hängen aneinander: Die Schrittliste (`WizardState.steps`) folgt der
/// Fassung, und wer nur die eine setzt, lässt den Wizard auf einem Schritt
/// stehen, den die Schrittleiste nicht mehr zeigt. Deshalb liegen sie hier
/// nebeneinander statt verstreut im `WizardCubit`.
class VorlagenFassung {
  const VorlagenFassung._();

  /// Welche Fassung nach dem Setzen von [template] gilt: die bisherige, solange
  /// die Vorlage sie hat — sonst die einzige, die sie hat. Mit `bisher: false`
  /// ist das die alte Regel „hat sie nur eine Fassung mit Auflistung, nimm sie".
  static bool fuer(FormTemplate template, {required bool bisher}) =>
      template.hasMitAuflistung && (bisher || !template.hasOhneAuflistung);

  /// Sichert zu, dass der aktuelle Schritt in [WizardState.steps] vorkommt —
  /// die Schrittliste hängt an [WizardState.mitAuflistung] und kann sich mit
  /// der Vorlage geändert haben.
  static WizardState mitGueltigemSchritt(WizardState zustand) =>
      zustand.steps.contains(zustand.currentStep)
      ? zustand
      : zustand.copyWith(currentStep: WizardStep.fillOut);
}
