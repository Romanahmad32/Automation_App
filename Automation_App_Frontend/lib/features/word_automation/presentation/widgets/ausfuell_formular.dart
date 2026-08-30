import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_prefill_matcher.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/aktive_platzhalter_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/formular_extraktion.dart';
import 'package:automation_app/features/word_automation/presentation/utils/neuerzeugung_bestaetigung.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/entwurf_hinweis.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/feld_einstellung_dialog.dart';
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
    // Erst die Platzhalter der Datei, dann das Formular: Die FormGroup soll
    // mit fertigem Wissen entstehen — käme die Menge nachträglich, baute der
    // Schlüssel das Formular neu und verwürfe die Eingaben (#35 Teil 2).
    final platzhalterStand = context.watch<AktivePlatzhalterCubit>().state;
    final wirdNochGelesen =
        platzhalterStand.pfad != wordDateiPfad ||
        (platzhalterStand.platzhalter == null &&
            !platzhalterStand.fehlgeschlagen);
    if (wirdNochGelesen) {
      return const Row(
        spacing: 10,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Text('Platzhalter werden gelesen …'),
        ],
      );
    }
    // Ließ sich die Datei nicht lesen, ist nichts bekannt — dann sperrt kein
    // Pflichtfeld (leere Menge), statt womöglich falsch zu blockieren.
    final aktivePlatzhalter = platzhalterStand.platzhalter ?? const <String>{};

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

    final angebot = wizardState.entwurfAngebot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (angebot != null)
          EntwurfHinweis(
            entwurf: angebot,
            onWeiterarbeiten: () =>
                context.read<WizardCubit>().uebernimmEntwurf(),
            onVerwerfen: () => context.read<WizardCubit>().verwirfEntwurf(),
          ),
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
          aufbauMarke: wizardState.aufbauMarke,
          aktivePlatzhalter: aktivePlatzhalter,
          onWerteGeaendert: (werte) =>
              context.read<WizardCubit>().setFormDataEntwurf(werte),
          onFeldBearbeiten: (feld) => _feldBearbeiten(context, feld),
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

  /// Der Stift am Feld: Einstellung im Dialog ändern, Vorlage sofort speichern,
  /// Formular stehen lassen (§5.3 aus dem Ausfüllschritt heraus).
  ///
  /// Die Vorlagenliste wird nur bei echter Änderung neu geladen — sie ist
  /// derselbe `@lazySingleton`, an dem der `TemplateSelector` hängt, und jedes
  /// Neuladen stößt dort ein Resync an.
  Future<void> _feldBearbeiten(BuildContext context, FieldData feld) async {
    final cubit = context.read<WizardCubit>();
    final vorlagen = context.read<FormTemplateOverviewBloc>();
    final melder = ScaffoldMessenger.of(context);

    final geaendert = await FeldEinstellungDialog.zeige(
      context,
      feld: feld,
      belegteNamen: [
        for (final anderes in template.fields)
          if (anderes.label != feld.label) anderes.label,
      ],
    );
    if (geaendert == null || _unveraendert(feld, geaendert)) return;

    final aenderung = await cubit.aktualisiereFeld(feld, geaendert);
    if (!aenderung.gespeichert) {
      melder.showSnackBar(
        const SnackBar(
          content: Text(
            'Die Feldeinstellung konnte nicht gespeichert werden. Die Vorlage '
            'bleibt unverändert.',
          ),
        ),
      );
      return;
    }
    if (!vorlagen.isClosed) vorlagen.add(LoadFormTemplatesEvent());

    final alterWert = aenderung.verdraengterWert;
    if (alterWert != null) {
      melder.showSnackBar(_zurueckholenMeldung(cubit, geaendert, alterWert));
    }
  }

  /// Die Meldung zu einem Wert, der der Vorbelegung gewichen ist. Sie steht
  /// länger als üblich: Der Anwalt liest gerade das Feld, nicht den unteren
  /// Bildschirmrand — und was hier verschwindet, hat er selbst getippt.
  static SnackBar _zurueckholenMeldung(
    WizardCubit cubit,
    FieldData feld,
    String alterWert,
  ) => SnackBar(
    content: Text('„${feld.label}" wurde aus der Vorbelegung neu befüllt.'),
    duration: const Duration(seconds: 8),
    action: SnackBarAction(
      label: 'Alten Wert zurückholen',
      // Die Meldung überlebt den Wizard: Wer die Seite verlässt, während sie
      // noch steht, drückte sonst auf einen geschlossenen Cubit.
      onPressed: () => cubit.isClosed
          ? null
          : cubit.stelleFeldWertWiederHer(feld.label, alterWert),
    ),
  );

  /// Ob der Dialog nichts geändert hat — dann bleibt der Dienst außen vor.
  ///
  /// Von Hand verglichen, weil [FieldData] sich nicht selbst vergleicht. Das zu
  /// ändern, zöge die Gleichheit von [FormTemplate] mit (`fields` steht in
  /// seinen `props`) und damit die Emit-Unterdrückung des Wizards — eine
  /// größere Änderung als die Frage hier wert ist.
  static bool _unveraendert(FieldData a, FieldData b) =>
      a.label == b.label &&
      a.inputType == b.inputType &&
      a.required == b.required &&
      a.datenquelle == b.datenquelle;

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
