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

  /// Breite eines Chips ohne Titel: Kreis (Durchmesser 32) plus Innenpolster
  /// der Zeile (12 links + 12 rechts).
  static const _chipOhneTitel = 56.0;

  /// Lücke zwischen Kreis und Titel, wenn der Titel gezeigt wird.
  static const _titelLuecke = 8.0;

  /// Kleinste Trennlinienbreite, mit der noch geprüft wird, ob eine
  /// Ausprägung überhaupt hineinpasst — die tatsächlich gerenderte Breite
  /// bestimmt weiter `Expanded`.
  static const _dividerMindestbreite = 16.0;

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
    final theme = Theme.of(context);

    final documentGenerated = editedState is EditedDocumentLoaded;
    final steps = wizardState.steps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      // Bei ausgeklappter Sidebar reichte die Breite für drei/vier volle
      // Titel samt Trennlinien nicht mehr — die Leiste lief rechts über
      // (Issue #57). `LayoutBuilder` entscheidet deshalb an der tatsächlich
      // verfügbaren Breite, ob alle Titel stehen bleiben, ob nur der aktive
      // Schritt seinen behält (die anderen zeigen nur ihre Ziffer), oder ob
      // selbst das nicht reicht und jeder Chip zusätzlich schrumpfen
      // (Ellipsis) muss.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final zeigeAlleTitel =
              _benoetigteBreite(
                context,
                steps,
                wizardState,
                theme,
                alleTitel: true,
              ) <=
              constraints.maxWidth;
          final passtKompakt =
              zeigeAlleTitel ||
              _benoetigteBreite(
                    context,
                    steps,
                    wizardState,
                    theme,
                    alleTitel: false,
                  ) <=
                  constraints.maxWidth;

          return Row(
            children: [
              for (final (position, step) in steps.indexed) ...[
                if (position > 0)
                  Expanded(
                    child: Divider(
                      color: _isEnabled(step, wizardState, documentGenerated)
                          ? theme.colorScheme.primary
                          : theme.dividerColor,
                    ),
                  ),
                _chip(
                  context,
                  position: position,
                  step: step,
                  wizardState: wizardState,
                  documentGenerated: documentGenerated,
                  zeigeTitel: zeigeAlleTitel || wizardState.currentStep == step,
                  // Passt selbst die kompakte Ausprägung (nur der aktive
                  // Titel) nicht mehr, bleibt nur noch, jeden Chip in eigenem
                  // Ellipsis schrumpfen zu lassen statt ihn abzuschneiden.
                  mussSchrumpfen: !passtKompakt,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required int position,
    required WizardStep step,
    required WizardState wizardState,
    required bool documentGenerated,
    required bool zeigeTitel,
    required bool mussSchrumpfen,
  }) {
    final isEnabled = _isEnabled(step, wizardState, documentGenerated);
    final chip = WizardStepChip(
      number: position + 1,
      title: _titles[step]!,
      isActive: wizardState.currentStep == step,
      isEnabled: isEnabled,
      showTitle: zeigeTitel,
      onTap: isEnabled
          ? () => context.read<WizardCubit>().goToStep(step)
          : null,
    );
    return mussSchrumpfen ? Flexible(child: chip) : chip;
  }

  /// Überschlägige Breite der Leiste ohne die Ziffern-Chips (deren Breite
  /// [_chipOhneTitel] schon einrechnet) — mit [TextPainter] auf dem echten
  /// `bodyMedium`-Stil gemessen, damit die Prüfung dieselbe Schriftskala
  /// sieht wie die gerenderten Titel.
  double _benoetigteBreite(
    BuildContext context,
    List<WizardStep> steps,
    WizardState wizardState,
    ThemeData theme, {
    required bool alleTitel,
  }) {
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      // Ohne die ambiente Textskala misst die Leiste enger, als sie
      // zeichnet, sobald Windows die Schrift vergrößert — die gerenderten
      // Titel nutzen genau diese Skala über `MediaQuery.textScalerOf`.
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    var breite = 0.0;
    try {
      for (final (position, step) in steps.indexed) {
        if (position > 0) breite += _dividerMindestbreite;
        final isActive = wizardState.currentStep == step;
        if (!alleTitel && !isActive) {
          breite += _chipOhneTitel;
          continue;
        }
        painter.text = TextSpan(
          text: _titles[step],
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        );
        painter.layout();
        breite += _chipOhneTitel + _titelLuecke + painter.width;
      }
    } finally {
      painter.dispose();
    }
    return breite;
  }
}
