import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/services/verwendete_felder.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_prefill_matcher.dart';
import 'package:automation_app/features/word_automation/domain/services/ausgangs_belegung.dart';
import 'package:automation_app/features/word_automation/domain/services/datenquelle_vorschlaege.dart';
import 'package:automation_app/features/word_automation/domain/services/schreiben_dateiname.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/aktive_platzhalter_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:automation_app/features/word_automation/presentation/utils/neuerzeugung_bestaetigung.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/eingaben_zuruecksetzen_button.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/feld_einstellung_dialog.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/form_template_builder.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/schreiben_nummer_hinweis.dart';
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
    // Wo der angefangene Stand den vorbelegten Wert überschreibt, nennt das
    // Feld **keine** Herkunft mehr (#133): Im Feld steht dann der Wert des
    // Anwalts, und „Vorbelegt aus dem Mandantenregister" darunter behauptete
    // eine Herkunft, die zum Angezeigten nicht mehr passt. Aus demselben Grund
    // zählt die Sammelzeile darüber diese Felder nicht mit.
    final ueberschrieben =
        wizardState.formDataEntwurf?.keys.toSet() ?? const <String>{};
    quellen.removeWhere((label, _) => ueberschrieben.contains(label));
    // Der Hinweis zählt nur, was dieses Schreiben auch einsetzt (#82) — sonst
    // nennt er sechs vorbelegte Felder, während oben drei stehen, und der
    // Anwalt sucht die anderen drei. Vorbelegt werden weiterhin alle: Die
    // eingeklappten behalten ihren Wert für die andere Vorlagenfassung.
    final sichtbarVorbelegt = [
      for (final eintrag in herkunft.entries)
        if (!ueberschrieben.contains(eintrag.key) &&
            VerwendeteFelder.wirdVerwendet(eintrag.key, aktivePlatzhalter))
          eintrag.value,
    ];
    final anzahlGespeichert = sichtbarVorbelegt
        .where((wert) => wert.quelle == PrefillQuelle.gespeichert)
        .length;

    // Was nicht *eindeutig* aus dem Bestand kommt, wird nicht geraten, sondern
    // am Feld zur Wahl gestellt (#17, §1.3) — etwa die drei Fahrzeuge eines
    // Mandanten, von denen das Register nicht weiss, welches im Unfall stand.
    final vorschlaege = DatenquelleVorschlaege.fuerFelder(
      template.fields,
      vorgang: vorgang,
      mandant: wizardState.selectedMandant,
    );

    // Der Abweichungsvergleich braucht mehr als [prefill]: Ein leeres
    // Datumsfeld zeigt das Formular selbst nicht leer, sondern mit dem
    // Datumsvorschlag (#133 Mangel 2) — ohne ihn hier zählte dieser Vorschlag
    // als Eingabe des Anwalts, der Zurücksetzen-Link erschiene ungefragt.
    final vorbelegungFuerVergleich = AusgangsBelegung.vollstaendig(
      fields: template.fields,
      initialValues: prefill,
      aktivePlatzhalter: aktivePlatzhalter,
    );

    // Sobald zum Vorgang ein Schreiben **gespeichert** ist: Korrektur oder
    // neues Schreiben? Null heisst „noch keins gespeichert" — dann ist die
    // Nummer die 1 und es gibt nichts zu fragen (§4.9, #133). Ein bloss
    // erzeugtes Schreiben zählt hier nicht mit: Es liegt im Arbeitsordner, den
    // die nächste Ablage ohnehin wegräumt.
    final gespeicherteNummer = wizardState.selectedVorgang?.schreibenNummer;
    final gibtGespeichertes =
        gespeicherteNummer != null && gespeicherteNummer >= 1;
    // Ohne Wahl wird nicht erzeugt — aber der Knopf bleibt nicht wortlos tot,
    // sondern sagt darüber, was fehlt (vgl. #130).
    final wahlFehlt = gibtGespeichertes && wizardState.neuesSchreiben == null;

    final formular = FormTemplateBuilder(
      formTemplate: template,
      initialValues: prefill,
      initialValueQuellen: quellen,
      // Der mitgeschriebene Tippstand überlebt damit den Neuaufbau des
      // Formulars, den eine nebenan bearbeitete Vorlage auslöst.
      erfassteWerte: wizardState.formDataEntwurf ?? const {},
      aufbauMarke: wizardState.aufbauMarke,
      aktivePlatzhalter: aktivePlatzhalter,
      vorschlaege: vorschlaege,
      weitereFehlende: [if (wahlFehlt) SchreibenNummerHinweis.wahlFehltHinweis],
      // Die Vorbelegung reist mit: Aufgehoben wird nur, was von ihr abweicht
      // (#133) — und was das ist, weiß nur diese Stelle, an der beides
      // zusammenläuft.
      //
      // `vorgang` ist an den Bau **dieses** Formulars gebunden. Meldet sich
      // sein `FormWertBeobachter` erst nach einem Vorgangswechsel (er meldet
      // eine ausstehende Änderung aus seinem `dispose()` heraus, das nach dem
      // Wechsel läuft), verwirft der Cubit die Meldung über genau diese
      // Referenz (Review-Nachbesserung #133).
      onWerteGeaendert: (werte) =>
          context.read<WizardCubit>().setFormDataEntwurf(
            werte,
            vorbelegung: vorbelegungFuerVergleich,
            fuerReferenz: vorgang?.referenz,
          ),
      onFeldBearbeiten: (feld) => _feldBearbeiten(context, feld),
      submitButtonLabel: Text(
        wizardState.mitAuflistung
            ? 'Weiter zur Schadensaufstellung'
            : 'Dokument erstellen',
      ),
      onSubmitted: (formData) =>
          _absenden(context, formData, vorbelegungFuerVergleich),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (gibtGespeichertes)
          SchreibenNummerHinweis(
            bisherigeNummer: gespeicherteNummer,
            letzterDokumentPfad: wizardState.selectedVorgang?.dokumentPfad,
            neuesSchreiben: wizardState.neuesSchreiben,
            onGeaendert: (wert) =>
                context.read<WizardCubit>().setNeuesSchreiben(wert),
          ),
        if (sichtbarVorbelegt.isNotEmpty)
          VorgangsdatenHinweis(
            anzahlFelder: sichtbarVorbelegt.length,
            anzahlGespeichert: anzahlGespeichert,
          ),
        // Der Weg zurück zur Vorbelegung — nur sichtbar, wenn ein Feld **dieser**
        // Vorlage überschrieben ist. Der Stand darf auch Felder anderer Vorlagen
        // tragen; die hier anzubieten hieße, einen Knopf zu zeigen, dessen
        // Wirkung nirgends zu sehen ist.
        EingabenZuruecksetzenButton(
          sichtbar: template.fields.any(
            (feld) => ueberschrieben.contains(feld.label),
          ),
        ),
        formular,
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
    // Vor dem await greifen: danach kann der BuildContext weg sein.
    final rueckmeldung = Rueckmeldung.von(context);

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
      rueckmeldung.fehler(
        'Die Feldeinstellung konnte nicht gespeichert werden. Die Vorlage '
        'bleibt unverändert.',
      );
      return;
    }
    if (!vorlagen.isClosed) vorlagen.add(LoadFormTemplatesEvent());

    final alterWert = aenderung.verdraengterWert;
    if (alterWert != null) {
      // Der Anwalt liest gerade das Feld, nicht den unteren Bildschirmrand —
      // die Meldung mit Aktion steht deshalb mindestens acht Sekunden
      // (`RueckmeldungsArt.mitAktionMindestens`). Was hier verschwindet, hat
      // er selbst getippt.
      rueckmeldung.hinweis(
        '„${feld.label}" wurde aus der Vorbelegung neu befüllt.',
        aktion: RueckmeldungsAktion(
          text: 'Alten Wert zurückholen',
          // Die Meldung überlebt den Wizard: Wer die Seite verlässt, während
          // sie noch steht, drückte sonst auf einen geschlossenen Cubit.
          beiDruck: () => cubit.isClosed
              ? null
              : cubit.stelleFeldWertWiederHer(feld.label, alterWert),
        ),
      );
    }
  }

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
    Map<String, String> vorbelegung,
  ) async {
    final cubit = context.read<WizardCubit>();
    final bloc = context.read<EditedDocumentBloc>();
    cubit.setFormData(formData, vorbelegung: vorbelegung);
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
    final vorgang = cubit.state.selectedVorgang;
    bloc.add(
      EditDocumentEvent(
        data: formData,
        damageListing: null,
        path: wordDateiPfad,
        vorsteuerabzugsberechtigt: cubit.state.vorsteuerabzugsberechtigt,
        outputFileName: schreibenDateiname(
          vorlagenname: template.templateName,
          nummer: naechsteSchreibenNummer(
            vorgang,
            // Hier ist die Wahl entweder getroffen oder bedeutungslos: Ohne
            // gespeichertes Schreiben ist die Nummer die 1, und mit einem
            // kommt der Knopf ohne Wahl gar nicht erst frei.
            neuesSchreiben: cubit.state.neuesSchreiben ?? false,
          ),
          versicherer: empfaengerFuerDateiname(vorgang),
        ),
        vorgangSchluessel: vorgang?.referenz,
      ),
    );
  }
}
