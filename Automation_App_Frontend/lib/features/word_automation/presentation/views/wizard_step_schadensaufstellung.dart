import 'package:automation_app/core/general_widgets/buttons/custom_rectangular_button.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/rvg_calculation_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/formular_extraktion.dart';
import 'package:automation_app/features/word_automation/presentation/utils/neuerzeugung_bestaetigung.dart';
import 'package:automation_app/features/word_automation/presentation/utils/schadenspositionen_pruefung.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/damage_listing_form.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/generation_overlay.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/schadensaufstellung_preview.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/schadensposition_fehlerliste.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/vorsteuer_checkbox_karte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Schritt "Schadensaufstellung" (nur bei Vorlagen mit Auflistung):
/// Schadenspositionen erfassen bzw. korrigieren, rechts die Live-Vorschau
/// der berechneten Aufstellung (Zwischensumme lokal, RVG-Kosten vom Backend).
/// Erst hier wird das Dokument erzeugt.
class WizardStepSchadensaufstellung extends StatelessWidget {
  const WizardStepSchadensaufstellung({super.key});

  void _onDamageListingChanged(
    BuildContext context,
    DamageListing listing,
    List<String> fehler,
  ) {
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
    context.read<WizardCubit>().setDamageListing(enriched, fehler: fehler);

    // Auch ohne Position wird das Ereignis abgeschickt, nicht unterdrückt: Es
    // ist zugleich der Reset. Wer es hier zurückhält, lässt den zuletzt
    // berechneten Betrag in der Vorschau stehen — und storniert über
    // restartable() auch keine noch laufende Anfrage zum alten Wert.
    final gegenstandswert = listing.items.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );
    context.read<RvgCalculationBloc>().add(
      CalculateRvgEvent(
        gegenstandswert: gegenstandswert,
        hatPositionen: listing.items.isNotEmpty,
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
    // Die Beanstandungen kommen aus dem Formular (es kennt auch die
    // angefangenen Zeilen) und sperren das Erzeugen hier, statt das Backend mit
    // einem HTTP 400 antworten zu lassen, das keine Zeile benennt.
    final fehler = wizardState.schadenspositionFehler;
    final canGenerate =
        wizardState.schadensaufstellungIstErzeugbar &&
        wizardState.formData != null &&
        loadedPath != null;

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
              // Die Beanstandungen bleiben, wie sie sind: Das Formular steht
              // unverändert da, nur die Umsatzsteuer hat sich geändert. Sie hier
              // aus `listing.items` neu abzuleiten, hiesse genau die Zeilen zu
              // verlieren, die es nicht in die Aufstellung schaffen — eine Zeile
              // ohne Bezeichnung mit -250 wäre nach dem Umschalten wieder
              // unbeanstandet, das Feld weiter rot und der Knopf frei.
              _onDamageListingChanged(
                context,
                listing,
                state.schadenspositionFehler,
              );
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
              _onDamageListingChanged(
                context,
                gespeichert,
                positionenFehler(gespeichert.items),
              );
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
                            const VorsteuerCheckboxKarte(),
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
                              onChanged: (listing, fehler) =>
                                  _onDamageListingChanged(
                                    context,
                                    listing,
                                    fehler,
                                  ),
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
              if (fehler.isNotEmpty)
                SchadenspositionFehlerliste(meldungen: fehler),
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
                          ? () async {
                              final bloc = context.read<EditedDocumentBloc>();
                              // Erzeugen ueberschreibt die vorige Fassung — bei
                              // Handarbeit in Word vorher fragen.
                              if (!await darfNeuErzeugen(context, bloc.state)) {
                                return;
                              }
                              final datum = ursachendatumAusFormular(
                                wizardState.selectedFormTemplate?.fields ??
                                    const [],
                                wizardState.formData!,
                              );
                              bloc.add(
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
                                  vorgangSchluessel:
                                      wizardState.selectedVorgang?.referenz,
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
