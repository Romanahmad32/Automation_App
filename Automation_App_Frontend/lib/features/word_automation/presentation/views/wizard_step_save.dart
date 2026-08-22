import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/akten_ablage_section.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/dokument_manuell_speichern.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/vorgang_abschliessen_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Schritt 4: Das bestätigte Dokument in die Akte des Mandanten ablegen (§6.1).
/// Ein Mandant kann mehrere Akten-Ordner haben (verschiedene Rubriken); der
/// Zielordner und der Unterordner (Fall) sind daher wählbar oder neu anlegbar.
/// Existiert der Mandant noch nicht, wird er hier — mit den Formulardaten
/// vorbelegt — angelegt. Alternativ kann das Dokument an einen frei wählbaren
/// Ort kopiert werden.
///
/// Ab der geglückten Ablage zeigt [EditedDocumentBloc] auf die Datei **in der
/// Akte**: der Arbeitsordner des Vorgangs wird dann gelöscht, damit nur die
/// bestätigte Fassung übrig bleibt (§4.6).
class WizardStepSave extends StatelessWidget {
  const WizardStepSave({super.key});

  @override
  Widget build(BuildContext context) {
    final editedState = context.watch<EditedDocumentBloc>().state;
    final outputPath = editedState is EditedDocumentLoaded
        ? editedState.path
        : null;

    if (outputPath == null) {
      return const Center(
        child: Text(
          'Es wurde noch kein Dokument erstellt.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AktenAblageSection(outputPath: outputPath),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              DokumentManuellSpeichern(outputPath: outputPath),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const VorgangAbschliessenSection(),
            ],
          ),
        ),
      ),
    );
  }
}
