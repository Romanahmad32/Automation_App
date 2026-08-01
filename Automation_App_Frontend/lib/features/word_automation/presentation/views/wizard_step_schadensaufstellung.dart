import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/rvg_calculation_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/formular_extraktion.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/damage_listing_form.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/generation_overlay.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/schadensaufstellung_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Schritt "Schadensaufstellung" (nur bei Vorlagen mit Auflistung):
/// Schadenspositionen erfassen bzw. korrigieren, rechts die Live-Vorschau
/// der berechneten Aufstellung (Zwischensumme lokal, RVG-Kosten vom Backend).
/// Erst hier wird das Dokument erzeugt.
class WizardStepSchadensaufstellung extends StatelessWidget {
  const WizardStepSchadensaufstellung({super.key});

  /// Die Vorsteuer-Checkbox in diesem Schritt ist ein synchronisiertes
  /// Spiegelbild der Checkbox aus dem Schritt "Vorlage wählen & ausfüllen"
  /// (gemeinsame Quelle: [WizardState.vorsteuerabzugsberechtigt]). Weil dieselbe
  /// Einstellung dort auch das Ankreuzen im Dokument steuert, wird eine Änderung
  /// hier zur Sicherheit per Dialog bestätigt, bevor sie übernommen wird.
  Future<void> _onVorsteuerToggleRequested(
    BuildContext context,
    bool value,
  ) async {
    final cubit = context.read<WizardCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vorsteuerabzugsberechtigung ändern?'),
        content: const Text(
          'Diese Einstellung stammt aus dem Schritt "Vorlage wählen & '
          'ausfüllen". Sie beeinflusst nicht nur die Umsatzsteuer in der '
          'Schadensaufstellung, sondern auch das Ankreuzen im Dokument '
          '("ist / ist nicht vorsteuerabzugsberechtigt"). Möchten Sie sie '
          'wirklich ändern?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ändern'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      // Nur das gemeinsame Cubit-Feld setzen; die Neuberechnung von applyVat
      // und RVG-Kosten erledigt der BlocListener in [build].
      cubit.setVorsteuerabzugsberechtigt(value);
    }
  }

  void _onDamageListingChanged(BuildContext context, DamageListing listing) {
    final wizardState = context.read<WizardCubit>().state;
    // applyVat (Umsatzsteuer ausweisen) ist die Umkehrung der
    // Vorsteuerabzugsberechtigung aus dem Ausfüll-Schritt.
    final applyVat = !wizardState.vorsteuerabzugsberechtigt;
    // Titelzeilen-Farbe aus den Einstellungen ergänzen, damit Vorschau und
    // erzeugtes Dokument dieselbe Farbe verwenden.
    final settingsState = context.read<KanzleiSettingsBloc>().state;
    final enriched = DamageListing(
      items: listing.items,
      gebuehrensatz: listing.gebuehrensatz,
      applyVat: applyVat,
      geschaeftsgebuehrOverride: listing.geschaeftsgebuehrOverride,
      auslagenpauschaleOverride: listing.auslagenpauschaleOverride,
      headerColorHex: settingsState is KanzleiSettingsLoaded
          ? settingsState.settings.tabellenkopfFarbeHex
          : null,
    );
    context.read<WizardCubit>().setDamageListing(enriched);

    final gegenstandswert = listing.items.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    context.read<RvgCalculationBloc>().add(
      CalculateRvgEvent(
        gegenstandswert: gegenstandswert,
        gebuehrensatz: listing.gebuehrensatz,
        applyVat: applyVat,
        geschaeftsgebuehrOverride: listing.geschaeftsgebuehrOverride,
        auslagenpauschaleOverride: listing.auslagenpauschaleOverride,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wizardState = context.watch<WizardCubit>().state;
    final documentState = context.watch<DocumentBloc>().state;
    final isGenerating =
        context.watch<EditedDocumentBloc>().state is EditedDocumentLoading;

    final loadedPath = documentState is DocumentLoaded
        ? documentState.path
        : null;
    final damageListing = wizardState.damageListing;
    final hasValidItems = damageListing?.items.isNotEmpty ?? false;
    final canGenerate =
        hasValidItems && wizardState.formData != null && loadedPath != null;

    return MultiBlocListener(
      listeners: [
        // Wird die Vorsteuerabzugsberechtigung geändert — egal ob hier oder im
        // Schritt "Vorlage wählen & ausfüllen" (beide Schritte bleiben im
        // IndexedStack gemountet) — dann applyVat und die RVG-Kosten der
        // bereits erfassten Aufstellung neu berechnen. Ohne das bliebe die
        // Berechnung auf dem alten Umsatzsteuer-Stand stehen.
        BlocListener<WizardCubit, WizardState>(
          listenWhen: (previous, current) =>
              previous.vorsteuerabzugsberechtigt !=
              current.vorsteuerabzugsberechtigt,
          listener: (context, state) {
            final listing = state.damageListing;
            if (listing != null) {
              _onDamageListingChanged(context, listing);
            }
          },
        ),
        // Beim Betreten des Schritts: Wurde zu diesem Vorgang schon einmal
        // eine Schadensaufstellung erfasst und ist hier noch keine erfasst,
        // die gespeicherte übernehmen (sichtbar und änderbar). Der Umweg über
        // _onDamageListingChanged normalisiert applyVat auf die aktuelle
        // Vorsteuer-Checkbox und stößt die RVG-Berechnung an.
        BlocListener<WizardCubit, WizardState>(
          listenWhen: (previous, current) =>
              previous.currentStep != current.currentStep &&
              current.currentStep == WizardStep.schadensaufstellung,
          listener: (context, state) {
            final gespeichert = state.selectedVorgang?.schadensaufstellung;
            if (state.damageListing == null && gespeichert != null) {
              _onDamageListingChanged(context, gespeichert);
            }
          },
        ),
      ],
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 450,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              margin: EdgeInsets.zero,
                              child: CheckboxListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                title: const Text(
                                  'Mandant ist vorsteuerabzugsberechtigt',
                                ),
                                subtitle: const Text(
                                  'Übernommen aus "Vorlage wählen & ausfüllen". '
                                  'Steuert die RVG-Umsatzsteuer dieser '
                                  'Aufstellung.',
                                ),
                                value: wizardState.vorsteuerabzugsberechtigt,
                                onChanged: (value) =>
                                    _onVorsteuerToggleRequested(
                                      context,
                                      value ?? false,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Schadenspositionen',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            // Key auf die Vorgangs-Referenz: Beim Wechsel des
                            // Vorgangs wird die Eingabe neu aufgebaut und mit
                            // dessen gespeicherter Aufstellung vorbelegt;
                            // während der Bearbeitung bleibt der State stehen.
                            DamageListingForm(
                              key: ValueKey(
                                'schadensaufstellung#'
                                '${wizardState.selectedVorgang?.referenz}',
                              ),
                              initialValue:
                                  damageListing ??
                                  wizardState
                                      .selectedVorgang
                                      ?.schadensaufstellung,
                              onChanged: (listing) =>
                                  _onDamageListingChanged(context, listing),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: SchadensaufstellungPreview(
                        damageListing: damageListing,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CustomRectangularButton(
                      onPressed: () => context.read<WizardCubit>().goToStep(
                        WizardStep.fillOut,
                      ),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Zurück'),
                    ),
                    const Spacer(),
                    CustomRectangularButton(
                      onPressed: canGenerate
                          ? () {
                              final datum = ursachendatumAusFormular(
                                wizardState.selectedFormTemplate?.fields ??
                                    const [],
                                wizardState.formData!,
                              );
                              context.read<EditedDocumentBloc>().add(
                                EditDocumentEvent(
                                  data: wizardState.formData!,
                                  damageListing: damageListing,
                                  path: loadedPath,
                                  vorsteuerabzugsberechtigt:
                                      wizardState.vorsteuerabzugsberechtigt,
                                  outputFileName: baueDateiname(
                                    loadedPath,
                                    datum,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Dokument erstellen'),
                    ),
                  ],
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
