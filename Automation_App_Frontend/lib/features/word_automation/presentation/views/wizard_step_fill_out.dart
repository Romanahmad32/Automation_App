import 'dart:io';

import 'package:automation_app/core/general_widgets/buttons/dropdowns/template_selector.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/pdf_preview_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ausfuell_formular.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/generation_overlay.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/pdf_preview_view.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/vorgang_selector.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/wizard_options_card.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/word_file_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../form_template_setup/domain/entities/form_template.dart';

/// Schritt 1: Formularvorlage wählen, Auflistungs-Version und
/// Vorsteuer-Status festlegen, Felder ausfüllen und das Dokument erzeugen
/// lassen. Rechts durchgehend die originalgetreue PDF-Vorschau der Vorlage.
class WizardStepFillOut extends StatelessWidget {
  const WizardStepFillOut({super.key});

  void _onTemplateSelected(BuildContext context, FormTemplate? template) {
    context.read<WizardCubit>().selectFormTemplate(template);
    _loadActiveWordFile(context);
  }

  /// Lädt die zur aktuellen Auswahl (ohne/mit Auflistung) passende Word-Datei.
  void _loadActiveWordFile(BuildContext context) {
    final path = context.read<WizardCubit>().state.activeWordFilePath;
    if (path == null) {
      return;
    }
    final documentBloc = context.read<DocumentBloc>();
    if (File(path).existsSync()) {
      documentBloc.add(SetDocumentPathEvent(path));
    } else {
      Rueckmeldung.zeigeFehler(
        context,
        'Die verknüpfte Word-Datei wurde nicht gefunden:\n$path',
        aktion: RueckmeldungsAktion(
          text: 'Neu verknüpfen',
          // Öffnet dieselbe Dateiauswahl wie der Knopf an der Word-Datei-
          // Zeile; die neue Wahl speichert der bestehende Listener dauerhaft
          // an der Vorlage (linkWordFileToTemplate).
          beiDruck: () => documentBloc.add(const SelectDocumentEvent()),
        ),
      );
    }
  }

  void _onMitAuflistungChanged(BuildContext context, bool value) {
    final cubit = context.read<WizardCubit>();
    final template = cubit.state.selectedFormTemplate;
    if (template == null) {
      return;
    }
    final targetPath = value
        ? template.wordFilePathMitAuflistung
        : template.wordFilePathOhneAuflistung;
    if (targetPath == null) {
      Rueckmeldung.zeigeHinweis(
        context,
        value
            ? 'Für diese Vorlage ist keine Version mit Auflistung hinterlegt. '
                  'Bitte im Vorlagen-Management eine Datei mit Auflistung '
                  'verknüpfen.'
            : 'Für diese Vorlage ist keine Version ohne Auflistung '
                  'hinterlegt. Bitte im Vorlagen-Management eine Datei ohne '
                  'Auflistung verknüpfen.',
      );
      return;
    }
    cubit.setMitAuflistung(value);
    _loadActiveWordFile(context);
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = context.watch<WizardCubit>().state;
    final documentState = context.watch<DocumentBloc>().state;
    final isGenerating =
        context.watch<EditedDocumentBloc>().state is EditedDocumentLoading;

    final selectedTemplate = wizardState.selectedFormTemplate;
    final loadedPath = documentState is DocumentLoaded
        ? documentState.path
        : null;

    return BlocListener<DocumentBloc, DocumentState>(
      listenWhen: (previous, current) =>
          current is DocumentLoaded && previous != current,
      listener: (context, state) async {
        // Manuell gewählte Datei dauerhaft am aktiven Slot der Vorlage
        // hinterlegen (no-op, wenn der Pfad bereits hinterlegt ist). Die
        // Vorlagenliste NUR dann neu laden, wenn tatsächlich eine neue
        // Verknüpfung gespeichert wurde: Ein Neuladen bei jeder Auswahl stößt
        // im TemplateSelector ein Resync an, das die gerade getroffene Auswahl
        // (Formular, Dateiname, PDF) wieder auf die vorherige zurücksetzen kann.
        final path = (state as DocumentLoaded).path;
        final overviewBloc = context.read<FormTemplateOverviewBloc>();
        final linked = await context.read<WizardCubit>().linkWordFileToTemplate(
          path,
        );
        if (linked && !overviewBloc.isClosed) {
          overviewBloc.add(LoadFormTemplatesEvent());
        }
      },
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const VorgangSelector(),
                      const SizedBox(height: 16),
                      TemplateSelector(
                        value: selectedTemplate,
                        onChanged: (value) =>
                            _onTemplateSelected(context, value),
                      ),
                      const SizedBox(height: 16),
                      if (selectedTemplate != null) ...[
                        WizardOptionsCard(
                          template: selectedTemplate,
                          mitAuflistung: wizardState.mitAuflistung,
                          vorsteuerabzugsberechtigt:
                              wizardState.vorsteuerabzugsberechtigt,
                          onMitAuflistungChanged: (value) =>
                              _onMitAuflistungChanged(context, value),
                          onVorsteuerChanged: (value) => context
                              .read<WizardCubit>()
                              .setVorsteuerabzugsberechtigt(value),
                        ),
                        const SizedBox(height: 16),
                        WordFileRow(loadedPath: loadedPath),
                        const SizedBox(height: 16),
                        if (loadedPath != null)
                          AusfuellFormular(
                            template: selectedTemplate,
                            wordDateiPfad: loadedPath,
                          ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Bitte zuerst eine Formularvorlage auswählen.',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: PdfPreviewView(
                  bloc: context.read<TemplatePdfPreviewBloc>(),
                  emptyHint: 'Keine Word-Datei geladen',
                ),
              ),
            ],
          ),
          if (isGenerating) const GenerationOverlay(),
        ],
      ),
    );
  }
}
