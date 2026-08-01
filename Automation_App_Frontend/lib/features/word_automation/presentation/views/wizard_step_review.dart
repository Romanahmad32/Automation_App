import 'dart:io';

import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/pdf_preview_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/pdf_preview_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Schritt 3: Das ausgefüllte Dokument als originalgetreues PDF prüfen.
/// Warnungen (nicht ersetzte Platzhalter) werden prominent angezeigt;
/// Korrekturen sind über "In Word öffnen" + "Vorschau aktualisieren" möglich.
class WizardStepReview extends StatelessWidget {
  const WizardStepReview({super.key});

  @override
  Widget build(BuildContext context) {
    final editedState = context.watch<EditedDocumentBloc>().state;
    final outputPath = editedState is EditedDocumentLoaded
        ? editedState.path
        : null;
    final warnings = editedState is EditedDocumentLoaded
        ? editedState.warnings
        : const <String>[];

    return Column(
      children: [
        if (warnings.isNotEmpty)
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Bitte prüfen — das Dokument enthält Warnungen:',
                      // Feste dunkle Schrift: der Container ist immer hellamber,
                      // daher darf die Farbe nicht aus dem (im Dark Mode hellen)
                      // Theme kommen, sonst hell-auf-hell und unlesbar.
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final warning in warnings)
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      '• $warning',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: PdfPreviewView(
            bloc: context.read<ResultPdfPreviewBloc>(),
            emptyHint: 'Noch kein Dokument ausgefüllt',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CustomRectangularButton(
                onPressed: () =>
                    context.read<WizardCubit>().goToStep(WizardStep.fillOut),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Zurück zum Ändern'),
              ),
              const SizedBox(width: 12),
              CustomRectangularButton(
                // Über den Windows-Shell-Befehl "start" statt url_launcher:
                // launchUrl öffnete die Datei erst beim zweiten Klick.
                onPressed: outputPath != null
                    ? () => Process.run('cmd', [
                        '/c',
                        'start',
                        '',
                        outputPath,
                      ], runInShell: false)
                    : null,
                icon: const Icon(Icons.edit_document),
                label: const Text('In Word öffnen'),
              ),
              const SizedBox(width: 12),
              CustomRectangularButton(
                onPressed: outputPath != null
                    ? () => context.read<ResultPdfPreviewBloc>().add(
                        LoadPdfPreviewEvent(outputPath),
                      )
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Vorschau aktualisieren'),
              ),
              const Spacer(),
              CustomRectangularButton(
                onPressed: outputPath != null
                    ? () =>
                          context.read<WizardCubit>().goToStep(WizardStep.save)
                    : null,
                icon: const Icon(Icons.check),
                label: const Text('Bestätigen'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
