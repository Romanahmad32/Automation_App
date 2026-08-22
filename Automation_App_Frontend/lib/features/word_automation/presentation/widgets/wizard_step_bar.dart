import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/wizard_step_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Horizontale Schrittleiste des Wizards. Erreichbare Schritte sind klickbar;
/// spätere Schritte werden erst freigeschaltet, wenn ihre Voraussetzungen
/// (Vorlage ausgefüllt bzw. Dokument erzeugt) erfüllt sind. Welche Schritte
/// überhaupt sichtbar sind, bestimmt die gewählte Formularvorlage
/// (mit/ohne Schadensaufstellung) über [WizardState.steps].
class WizardStepBar extends StatelessWidget {
  static const _titles = {
    WizardStep.fillOut: 'Vorlage wählen & ausfüllen',
    WizardStep.schadensaufstellung: 'Schadensaufstellung',
    WizardStep.review: 'Dokument begutachten',
    WizardStep.save: 'Speichern & weiter',
  };

  const WizardStepBar({super.key});

  bool _isEnabled(
    WizardStep step,
    WizardState wizardState,
    bool documentGenerated,
  ) {
    return switch (step) {
      WizardStep.fillOut => true,
      WizardStep.schadensaufstellung => wizardState.formData != null,
      WizardStep.review || WizardStep.save => documentGenerated,
    };
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = context.watch<WizardCubit>().state;
    final editedState = context.watch<EditedDocumentBloc>().state;

    final documentGenerated = editedState is EditedDocumentLoaded;
    final steps = wizardState.steps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          for (final (position, step) in steps.indexed) ...[
            if (position > 0)
              Expanded(
                child: Divider(
                  color: _isEnabled(step, wizardState, documentGenerated)
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor,
                ),
              ),
            WizardStepChip(
              number: position + 1,
              title: _titles[step]!,
              isActive: wizardState.currentStep == step,
              isEnabled: _isEnabled(step, wizardState, documentGenerated),
              onTap: _isEnabled(step, wizardState, documentGenerated)
                  ? () => context.read<WizardCubit>().goToStep(step)
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}
