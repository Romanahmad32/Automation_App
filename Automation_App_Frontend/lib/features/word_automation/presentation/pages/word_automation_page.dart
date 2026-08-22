import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/page_refresh/page_refresh_scope.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/ablage_cubit/ablage_cubit.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_rueckfluss.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/pdf_preview_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/rvg_calculation_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/views/wizard_step_fill_out.dart';
import 'package:automation_app/features/word_automation/presentation/views/wizard_step_review.dart';
import 'package:automation_app/features/word_automation/presentation/views/wizard_step_save.dart';
import 'package:automation_app/features/word_automation/presentation/views/wizard_step_schadensaufstellung.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/wizard_step_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';

@RoutePage()
class WordAutomationPage extends StatelessWidget implements AutoRouteWrapper {
  const WordAutomationPage({super.key});

  @override
  Widget wrappedRoute(BuildContext context) {
    return PageRefreshScope(
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => getIt<DocumentBloc>()),
          BlocProvider(create: (context) => getIt<EditedDocumentBloc>()),
          BlocProvider(create: (context) => getIt<WizardCubit>()),
          BlocProvider(create: (context) => getIt<TemplatePdfPreviewBloc>()),
          BlocProvider(create: (context) => getIt<ResultPdfPreviewBloc>()),
          BlocProvider(create: (context) => getIt<RvgCalculationBloc>()),
          // Steuert die Akten-Ablage im Speicherschritt (§3.6).
          BlocProvider(create: (context) => getIt<AblageCubit>()),
          // Liefert die Titelzeilen-Farbe der Schadensaufstellung aus den
          // Einstellungen für Vorschau und Dokumenterzeugung.
          BlocProvider(
            create: (context) =>
                getIt<KanzleiSettingsBloc>()
                  ..add(const LoadKanzleiSettingsEvent()),
          ),
          // Singleton-Bloc: per .value einbinden, damit er beim Dispose der
          // Seite nicht geschlossen wird.
          BlocProvider.value(
            value: getIt<FormTemplateOverviewBloc>()
              ..add(LoadFormTemplatesEvent()),
          ),
        ],
        child: this,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Sobald eine Vorlage gewählt ist, ihre PDF-Vorschau laden.
        BlocListener<DocumentBloc, DocumentState>(
          listenWhen: (previous, current) =>
              current is DocumentLoaded && previous != current,
          listener: (context, state) {
            final path = (state as DocumentLoaded).path;
            context.read<TemplatePdfPreviewBloc>().add(
              LoadPdfPreviewEvent(path),
            );
          },
        ),
        BlocListener<DocumentBloc, DocumentState>(
          listenWhen: (previous, current) => current is DocumentError,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text((state as DocumentError).message),
                duration: const Duration(seconds: 3),
              ),
            );
          },
        ),
        // Erfolgreich erzeugtes Dokument: zur Begutachtung springen
        // und die Ergebnis-Vorschau laden.
        BlocListener<EditedDocumentBloc, EditedDocumentState>(
          listener: (context, state) {
            switch (state) {
              case EditedDocumentLoaded():
                context.read<WizardCubit>().goToStep(WizardStep.review);
                context.read<ResultPdfPreviewBloc>().add(
                  LoadPdfPreviewEvent(state.path),
                );
                // Erzeugtes Schreiben am Vorgang vermerken: Dokumentpfad
                // hinterlegen, den Status auf „Erstellt" weiterschalten (nur
                // vorwärts, ein bereits abgelegter/versendeter Vorgang wird
                // nicht zurückgesetzt) und die bestätigten Wizard-Eingaben
                // (Formularwerte, Schadensaufstellung, explizit zugeordnete
                // Unfalldaten) in den Vorgang zurückfließen lassen, damit das
                // nächste Schreiben zum selben Vorgang vorbelegt startet.c
                final wizardState = context.read<WizardCubit>().state;
                // Immer den frischesten Stand aus dem VorgangCubit verwenden:
                // der im Wizard gewählte Vorgang kann inzwischen aktualisiert
                // worden sein (z. B. Antwort eingetroffen) — eine Kopie des
                // alten Stands würde diese Daten überschreiben.
                final gewaehlt = wizardState.selectedVorgang;
                final vorgang = gewaehlt == null
                    ? null
                    : getIt<VorgangCubit>().findeZuReferenz(
                            gewaehlt.referenz,
                          ) ??
                          gewaehlt;
                if (vorgang != null) {
                  final status =
                      vorgang.status.index < VorgangStatus.erstellt.index
                      ? VorgangStatus.erstellt
                      : vorgang.status;
                  var aktualisiert = vorgang.copyWith(
                    status: status,
                    dokumentPfad: state.path,
                  );
                  final formData = wizardState.formData;
                  if (formData != null) {
                    aktualisiert = VorgangRueckfluss.uebernehmeWizardErgebnis(
                      aktualisiert,
                      fields:
                          wizardState.selectedFormTemplate?.fields ?? const [],
                      formData: formData,
                      schadensaufstellung: wizardState.damageListing,
                    );
                  }
                  getIt<VorgangCubit>().aktualisiere(aktualisiert);
                  // Auswahl im Wizard auf den neuen Stand heben, damit ein
                  // weiteres Schreiben im selben Durchlauf die gerade
                  // bestätigten Werte vorbelegt bekommt.
                  context.read<WizardCubit>().uebernehmeVorgangsStand(
                    aktualisiert,
                  );
                }
              case EditedDocumentError():
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    duration: const Duration(seconds: 3),
                  ),
                );
              default:
                break;
            }
          },
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'Word Vorlagen ausfüllen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          actions: const [PageRefreshButton()],
        ),
        body: Column(
          children: [
            const WizardStepBar(),
            const Divider(height: 1),
            Expanded(
              child: BlocBuilder<WizardCubit, WizardState>(
                buildWhen: (previous, current) =>
                    previous.currentStep != current.currentStep,
                builder: (context, state) {
                  // IndexedStack hält alle Schritte am Leben, damit z. B.
                  // die Formulareingaben beim Vor- und Zurückblättern
                  // erhalten bleiben. Es liegen immer alle vier Views auf
                  // ihren festen Enum-Indizes — der Schadensaufstellungs-
                  // Schritt ist bei Vorlagen ohne Auflistung schlicht nie
                  // erreichbar (Guard in WizardCubit.goToStep).
                  return IndexedStack(
                    index: state.currentStep.index,
                    children: const [
                      WizardStepFillOut(),
                      WizardStepSchadensaufstellung(),
                      WizardStepReview(),
                      WizardStepSave(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
