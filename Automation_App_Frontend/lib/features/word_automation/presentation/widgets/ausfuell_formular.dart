import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_prefill_matcher.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/formular_extraktion.dart';
import 'package:automation_app/features/word_automation/presentation/utils/neuerzeugung_bestaetigung.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/form_template_builder.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/vorgangsdaten_hinweis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Ausfüllteil von Schritt 1: Daten des gewählten Vorgangs (Mandant +
/// Antwort + Rechtsgebiet) auf die Vorlagenfelder mappen und sichtbar
/// vorbelegen (§3 → §4.4), das Formular zeigen und beim Absenden entweder zur
/// Schadensaufstellung weiterschalten oder das Dokument erzeugen lassen. Ohne
/// gewählten Vorgang bleibt die Erfassung frei.
class AusfuellFormular extends StatelessWidget {
  final FormTemplate template;

  /// Die geladene Word-Datei, aus der erzeugt wird.
  final String wordDateiPfad;

  const AusfuellFormular({
    super.key,
    required this.template,
    required this.wordDateiPfad,
  });

  @override
  Widget build(BuildContext context) {
    final wizardState = context.watch<WizardCubit>().state;
    final vorgang = wizardState.selectedVorgang;
    final herkunft = vorgang == null
        ? const <String, PrefillWert>{}
        : VorgangPrefillMatcher.matchTemplateFieldsMitHerkunft(
            template.fields,
            vorgang,
            mandant: wizardState.selectedMandant,
          );
    final prefill = herkunft.map((label, wert) => MapEntry(label, wert.wert));
    final quellen = herkunft.map(
      (label, wert) => MapEntry(label, wert.quelle.beschreibung),
    );
    final anzahlGespeichert = herkunft.values
        .where((wert) => wert.quelle == PrefillQuelle.gespeichert)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (prefill.isNotEmpty)
          VorgangsdatenHinweis(
            anzahlFelder: prefill.length,
            anzahlGespeichert: anzahlGespeichert,
          ),
        FormTemplateBuilder(
          formTemplate: template,
          initialValues: prefill,
          initialValueQuellen: quellen,
          // Der mitgeschriebene Tippstand überlebt damit den Neuaufbau des
          // Formulars, den eine nebenan bearbeitete Vorlage auslöst.
          erfassteWerte: wizardState.formDataEntwurf ?? const {},
          onWerteGeaendert: (werte) =>
              context.read<WizardCubit>().setFormDataEntwurf(werte),
          submitButtonLabel: Text(
            wizardState.mitAuflistung
                ? 'Weiter zur Schadensaufstellung'
                : 'Dokument erstellen',
          ),
          onSubmitted: (formData) => _absenden(context, formData),
        ),
      ],
    );
  }

  Future<void> _absenden(
    BuildContext context,
    Map<String, String> formData,
  ) async {
    final cubit = context.read<WizardCubit>();
    final bloc = context.read<EditedDocumentBloc>();
    cubit.setFormData(formData);
    if (cubit.state.mitAuflistung) {
      // Generierung erst am Ende des Schadensaufstellungs-Schritts.
      cubit.goToStep(WizardStep.schadensaufstellung);
      return;
    }
    // Erzeugen ueberschreibt die vorige Fassung — bei Handarbeit in Word
    // vorher fragen.
    if (!await darfNeuErzeugen(context, bloc.state)) {
      return;
    }
    final datum = ursachendatumAusFormular(template.fields, formData);
    bloc.add(
      EditDocumentEvent(
        data: formData,
        damageListing: null,
        path: wordDateiPfad,
        vorsteuerabzugsberechtigt: cubit.state.vorsteuerabzugsberechtigt,
        outputFileName: baueDateiname(wordDateiPfad, datum),
        vorgangSchluessel: cubit.state.selectedVorgang?.referenz,
      ),
    );
  }
}
