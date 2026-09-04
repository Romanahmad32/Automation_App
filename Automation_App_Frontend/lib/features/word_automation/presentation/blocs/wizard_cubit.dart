import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/utils/entwurfs_sicherung.dart';
import 'package:automation_app/features/word_automation/presentation/utils/feld_stand.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'wizard_state.dart';

/// Was aus einer geänderten Feldeinstellung wurde: ob sie am Bestand ankam,
/// und welcher erfasste Wert dabei der Vorbelegung gewichen ist (`null` =
/// keiner). Die Meldung im Ausfüllschritt bietet ihn zum Zurückholen an.
typedef FeldAenderung = ({bool gespeichert, String? verdraengterWert});

@injectable
class WizardCubit extends Cubit<WizardState> {
  final UseCase<FormTemplate, UpdateFormTemplateParams> _updateFormTemplate;
  final UseCase<List<Mandant>, NoParams> _getMandanten;

  /// Der app-weite Vorgangsspeicher — hier nur noch, um einen verworfenen
  /// Entwurf auch am Vorgang wegzuräumen.
  final VorgangCubit _vorgaenge;

  /// Ablage des angefangenen Stands; hält Zeitgeber und Bestätigt-Marke.
  final EntwurfsSicherung _entwurf;

  /// Wie lange nach der letzten Änderung gewartet wird, bevor der Entwurf zum
  /// Dienst geht — die Zusage, an der sich Aufrufer und Tests ausrichten.
  static const entwurfVerzoegerung = EntwurfsSicherung.verzoegerung;

  WizardCubit(
    this._updateFormTemplate,
    this._getMandanten,
    VorgangCubit vorgaenge,
  ) : _vorgaenge = vorgaenge,
      _entwurf = EntwurfsSicherung(vorgaenge),
      super(const WizardState());

  /// Wählt den Vorgang, aus dem das Schreiben erstellt wird. Die Auswahl wird
  /// sofort übernommen (die Vorbelegung reagiert), der verknüpfte Mandant aus
  /// dem Register danach asynchron nachgeladen — die Antwortdaten stecken schon
  /// im Vorgang, die Mandanten-Stammdaten ergänzen Name und Anschrift.
  ///
  /// Die Schadensaufstellung fällt dabei weg, wie schon bei [selectFormTemplate]
  /// und [setMitAuflistung]: Sie gehört zum vorigen Vorgang. Blieb sie stehen,
  /// zeigte der nächste Vorgang die Positionen des vorigen — und der
  /// Listener des Schadensaufstellungs-Schritts lud die **eigene** gespeicherte
  /// Aufstellung nie nach, weil er nur bei `damageListing == null` greift.
  ///
  /// Aus demselben Grund fällt der Tippstand weg: Er gehört zum vorigen
  /// Vorgang und hätte beim Neuaufbau des Formulars Vorrang vor der Vorbelegung
  /// des neuen. Ein am neuen Vorgang liegender Entwurf wird **angeboten**
  /// ([WizardState.entwurfAngebot]), nicht eingesetzt.
  Future<void> selectVorgang(Vorgang? vorgang) async {
    _entwurf.beende();
    emit(
      state.copyWith(
        selectedVorgang: () => vorgang,
        selectedMandant: () => null,
        damageListing: () => null,
        schadenspositionFehler: const [],
        formDataEntwurf: () => null,
        entwurfAngebot: () => vorgang?.entwurf,
        // Die Entscheidung gehört dem Vorgang, aus dem sie stammt: Am neuen
        // steht eine andere Nummer, und „neues Schreiben" hiesse dort etwas
        // anderes als hier.
        neuesSchreiben: false,
      ),
    );
    if (vorgang?.mandantId == null) return;

    final result = await _getMandanten(const NoParams());
    if (isClosed) return;
    // Inzwischen umgewählt? Dann das Ergebnis verwerfen.
    if (state.selectedVorgang?.referenz != vorgang!.referenz) return;
    switch (result) {
      case Right(value: final mandanten):
        Mandant? gefunden;
        for (final mandant in mandanten) {
          if (mandant.id == vorgang.mandantId) {
            gefunden = mandant;
            break;
          }
        }
        emit(state.copyWith(selectedMandant: () => gefunden));
      case Left():
        break;
    }
  }

  /// Übernimmt den angebotenen Entwurf in die Eingabe: Werte und Aufstellung
  /// werden gesetzt, die Leiste verschwindet, und [WizardState.aufbauMarke]
  /// zwingt das Formular zum Neuaufbau — ohne sie hätte der Anwalt auf
  /// „Weiterarbeiten" gedrückt und nichts passieren sehen.
  void uebernimmEntwurf() {
    final angebot = state.entwurfAngebot;
    if (angebot == null) return;
    emit(
      state.copyWith(
        formDataEntwurf: () => angebot.feldWerte,
        damageListing: () => angebot.schadensaufstellung,
        entwurfAngebot: () => null,
        aufbauMarke: state.aufbauMarke + 1,
      ),
    );
  }

  /// Verwirft den angebotenen Entwurf — auch am Vorgang, sonst stünde er beim
  /// nächsten Einstieg wieder da.
  void verwirfEntwurf() {
    final referenz = state.selectedVorgang?.referenz;
    emit(state.copyWith(entwurfAngebot: () => null));
    if (referenz != null) _vorgaenge.sichereEntwurf(referenz, null);
  }

  /// Ersetzt den gewählten Vorgang durch seinen aktualisierten Stand (z. B.
  /// nach dem Rückfluss der Wizard-Eingaben in den Vorgang), ohne den
  /// Mandanten neu zu laden. No-op, wenn inzwischen ein anderer Vorgang
  /// gewählt wurde.
  void uebernehmeVorgangsStand(Vorgang vorgang) {
    final aktuell = state.selectedVorgang;
    if (aktuell == null ||
        !Vorgang.gleicheReferenz(aktuell.referenz, vorgang.referenz)) {
      return;
    }
    _entwurf.markiereBestaetigt();
    // Mit dem erzeugten Schreiben ist die Entscheidung verbraucht: Wer jetzt
    // noch einmal auf „erstellen" drückt, korrigiert genau dieses Schreiben.
    // Ohne das Zurücksetzen zählte jede Korrektur eine Nummer weiter.
    emit(state.copyWith(selectedVorgang: () => vorgang, neuesSchreiben: false));
  }

  /// Die Entscheidung des Anwalts, ob das nächste Erzeugen ein **neues**
  /// Schreiben ist oder die Korrektur des vorigen (§4.9). Gestellt wird sie in
  /// der Leiste des Ausfüllschritts, und nur ab dem zweiten Schreiben eines
  /// Vorgangs — vorher gibt es nichts zu entscheiden.
  void setNeuesSchreiben(bool neuesSchreiben) {
    emit(state.copyWith(neuesSchreiben: neuesSchreiben));
  }

  void goToStep(WizardStep step) {
    if (!state.steps.contains(step)) {
      return;
    }
    emit(state.copyWith(currentStep: step));
    // Einen Eingabeschritt zu verlassen ist der Punkt, an dem der Anwalt mit
    // dem Bisherigen fertig ist — hier wird nicht auf den Takt gewartet. Der
    // Sprung ins Begutachten ist keiner: Dorthin kommt man nur über ein
    // erzeugtes Dokument, und dann ist der Stand bestätigt statt angefangen.
    if (step == WizardStep.fillOut || step == WizardStep.schadensaufstellung) {
      sichereEntwurfJetzt();
    }
  }

  /// Setzt die gewählte Vorlage — und unterscheidet dabei zwei Fälle, die
  /// vorher denselben Weg gingen:
  ///
  /// **Wechsel** (andere Vorlage, oder gar keine mehr): Die Eingaben gehören
  /// zur vorherigen Vorlage und werden verworfen.
  ///
  /// **Aktualisierung** (dieselbe ID, neuer Stand): Sie kommt nicht vom
  /// Anwalt, sondern vom Abgleich im `TemplateSelector` — der vergleicht die
  /// Auswahl per Wert mit der neu geladenen Liste und meldet jede andernorts
  /// bearbeitete Vorlage als Auswahl. Wer also mitten im Ausfüllen ein Feld
  /// auf „nicht erforderlich" stellt, bekam hier alles gelöscht: Eingaben,
  /// Schadensaufstellung, sogar den Schritt (denn [WizardState.mitAuflistung]
  /// fiel auf die Vorgabe zurück und nahm `schadensaufstellung` aus
  /// [WizardState.steps]). Behalten wird deshalb alles, was weiter gilt.
  void selectFormTemplate(FormTemplate? template) {
    if (template != null && template.id == state.selectedFormTemplate?.id) {
      emit(
        _mitGueltigemSchritt(
          state.copyWith(
            selectedFormTemplate: () => template,
            mitAuflistung: _fassungFuer(template, state.mitAuflistung),
          ),
        ),
      );
      return;
    }

    emit(
      _mitGueltigemSchritt(
        state.copyWith(
          selectedFormTemplate: () => template,
          mitAuflistung: template != null && _fassungFuer(template, false),
          vorsteuerabzugsberechtigt: true,
          damageListing: () => null,
          schadenspositionFehler: const [],
          formData: () => null,
          formDataEntwurf: () => null,
        ),
      ),
    );
  }

  /// Schaltet zwischen Version ohne/mit Auflistung um. Eingaben des
  /// Schadensaufstellungs-Schritts werden beim Wechsel verworfen.
  void setMitAuflistung(bool mitAuflistung) {
    emit(
      _mitGueltigemSchritt(
        state.copyWith(
          mitAuflistung: mitAuflistung,
          damageListing: () => null,
          schadenspositionFehler: const [],
        ),
      ),
    );
  }

  /// Welche Fassung nach dem Setzen von [template] gilt: die bisherige, solange
  /// die Vorlage sie hat — sonst die einzige, die sie hat. Mit `bisher: false`
  /// ist das die alte Regel „hat sie nur eine Fassung mit Auflistung, nimm sie".
  static bool _fassungFuer(FormTemplate template, bool bisher) =>
      template.hasMitAuflistung && (bisher || !template.hasOhneAuflistung);

  /// Sichert zu, dass der aktuelle Schritt in [WizardState.steps] vorkommt —
  /// die Schrittliste hängt an [WizardState.mitAuflistung] und kann sich mit
  /// der Vorlage geändert haben.
  static WizardState _mitGueltigemSchritt(WizardState zustand) =>
      zustand.steps.contains(zustand.currentStep)
      ? zustand
      : zustand.copyWith(currentStep: WizardStep.fillOut);

  void setVorsteuerabzugsberechtigt(bool value) {
    emit(state.copyWith(vorsteuerabzugsberechtigt: value));
  }

  /// Stand und Beanstandungen kommen zusammen aus dem Formular und werden
  /// zusammen gesetzt — getrennt gesetzt könnten sie auseinanderlaufen, und
  /// dann sperrte oder öffnete der Knopf zum falschen Stand.
  void setDamageListing(
    DamageListing? damageListing, {
    List<String> fehler = const [],
  }) {
    emit(
      state.copyWith(
        damageListing: () => damageListing,
        schadenspositionFehler: fehler,
      ),
    );
    _planeSicherung();
  }

  /// Übernimmt den **abgesendeten** Stand des Ausfüll-Formulars. Der Entwurf
  /// zieht mit, damit ein späterer Neuaufbau nicht auf einen älteren Tippstand
  /// zurückfällt.
  void setFormData(Map<String, String>? formData) {
    emit(
      state.copyWith(
        formData: () => formData,
        formDataEntwurf: () => formData ?? state.formDataEntwurf,
      ),
    );
    _planeSicherung();
  }

  /// Schreibt den laufenden Tippstand mit (entprellt aus dem Formular). Gibt
  /// **keine** Freigabe: Dafür ist [setFormData] zuständig.
  void setFormDataEntwurf(Map<String, String> werte) {
    emit(state.copyWith(formDataEntwurf: () => werte));
    _planeSicherung();
  }

  /// Legt den angefangenen Stand sofort am Vorgang ab (Einzelheiten und
  /// Abbruchgründe in [EntwurfsSicherung.jetzt]).
  void sichereEntwurfJetzt() => _entwurf.jetzt(
    referenz: state.selectedVorgang?.referenz,
    werte: state.formDataEntwurf,
    aufstellung: state.damageListing,
  );

  void _planeSicherung() => _entwurf.plane(
    sichereEntwurfJetzt,
    hatVorgang: state.selectedVorgang != null,
  );

  /// Speichert eine im **Ausfüllschritt** geänderte Feldeinstellung direkt an
  /// der Vorlage. Das ist der Griff, der #37 den Auslöser nimmt: Wer bloß ein
  /// Feld umbenennen oder auf „nicht erforderlich" stellen will, muss dafür die
  /// Seite nicht mehr verlassen — und verliert also nicht, was er bis dahin
  /// eingetippt hat.
  ///
  /// Bei einer **Umbenennung** zieht der erfasste Wert mit: [WizardState.formData]
  /// und [WizardState.formDataEntwurf] sind nach Feldnamen geschlüsselt, das
  /// Feld fände seinen Wert sonst nur unter einem Namen, den die Vorlage nicht
  /// mehr kennt — derselbe Verlust wie im Ausgangsfall, eine Ebene tiefer.
  ///
  /// Wurde die **Datenquelle** geändert und liefert die neue zum gewählten
  /// Vorgang wirklich etwas, weicht der erfasste Wert dieser Vorbelegung: Wer
  /// sagt „dieses Feld kommt von dort", meint den Wert von dort. Er kommt als
  /// [FeldAenderung.verdraengterWert] zurück, damit die Meldung ihn anbieten
  /// kann — verloren geht hier nichts still.
  Future<FeldAenderung> aktualisiereFeld(FieldData alt, FieldData neu) async {
    const gescheitert = (gespeichert: false, verdraengterWert: null);
    final template = state.selectedFormTemplate;
    if (template == null) return gescheitert;

    final felder = [
      for (final feld in template.fields) feld.label == alt.label ? neu : feld,
    ];
    final result = await _updateFormTemplate(
      UpdateFormTemplateParams(template.copyWith(fields: felder)),
    );
    if (isClosed) return gescheitert;
    switch (result) {
      case Right(value: final gespeichert):
        final weicht = FeldStand.weichtDerVorbelegung(
          alt,
          neu,
          vorgang: state.selectedVorgang,
          mandant: state.selectedMandant,
        );
        final stand = FeldStand.nachAenderung(
          formData: state.formData,
          formDataEntwurf: state.formDataEntwurf,
          alt: alt,
          neu: neu,
          weicht: weicht,
        );
        emit(
          state.copyWith(
            selectedFormTemplate: () => gespeichert,
            formData: () => stand.formData,
            formDataEntwurf: () => stand.formDataEntwurf,
            // Ohne die Marke bliebe die FormGroup womöglich stehen: Setzt der
            // Anwalt die Quelle auf das, was die Namens-Heuristik ohnehin
            // erkannt hatte, ist die Vorbelegung Zeichen für Zeichen dieselbe
            // — und nur sie steht im Schlüssel, der erfasste Stand nicht.
            aufbauMarke: weicht ? state.aufbauMarke + 1 : state.aufbauMarke,
          ),
        );
        return (gespeichert: true, verdraengterWert: stand.verdraengterWert);
      case Left():
        return gescheitert;
    }
  }

  /// Holt einen Wert zurück, den [aktualisiereFeld] der Vorbelegung überlassen
  /// hat („Alten Wert zurückholen" an der Meldung).
  ///
  /// Zurückgeholt wird der **Wert**, nicht die Feldeinstellung: Die neue
  /// Datenquelle bleibt an der Vorlage stehen. Beides zusammen zurückzudrehen
  /// hieße, eine gespeicherte Vorlagenänderung an einer Meldung aufzuhängen,
  /// die nach ein paar Sekunden von selbst verschwindet.
  void stelleFeldWertWiederHer(String label, String wert) {
    emit(
      state.copyWith(
        formDataEntwurf: () => {...?state.formDataEntwurf, label: wert},
        // Der erfasste Stand steht bewusst nicht im Schlüssel der FormGroup —
        // ohne die Marke sähe der Anwalt auf seinen Klick hin nichts geschehen.
        aufbauMarke: state.aufbauMarke + 1,
      ),
    );
  }

  /// Hinterlegt die manuell gewählte Word-Datei dauerhaft am **aktiven Slot**
  /// (je nach [WizardState.mitAuflistung]) der gewählten Formularvorlage, damit
  /// sie beim nächsten Mal automatisch lädt. Fehler beim Speichern sind
  /// unkritisch (die Datei ist trotzdem geladen).
  ///
  /// Gibt `true` zurück, wenn dadurch tatsächlich eine neue Verknüpfung
  /// gespeichert wurde. Nur dann muss die Vorlagenliste neu geladen werden –
  /// ein Neuladen bei jeder Auswahl löst sonst ein Resync aus, das eine
  /// gerade getroffene Auswahl wieder zurücksetzen kann.
  Future<bool> linkWordFileToTemplate(String wordFilePath) async {
    final template = state.selectedFormTemplate;
    if (template == null || state.activeWordFilePath == wordFilePath) {
      return false;
    }

    final updated = state.mitAuflistung
        ? template.copyWith(wordFilePathMitAuflistung: () => wordFilePath)
        : template.copyWith(wordFilePathOhneAuflistung: () => wordFilePath);
    final result = await _updateFormTemplate(UpdateFormTemplateParams(updated));
    switch (result) {
      case Right():
        emit(state.copyWith(selectedFormTemplate: () => updated));
        return true;
      case Left():
        return false;
    }
  }

  /// Beim Verlassen der Seite noch einmal sichern — das schließt die Lücke der
  /// letzten Sekunden, die der Takt sonst kostet. Der Empfänger
  /// ([VorgangCubit]) lebt weiter, seine Ablage läuft also auch dann noch, wenn
  /// dieser Cubit schon geschlossen ist.
  @override
  Future<void> close() {
    sichereEntwurfJetzt();
    _entwurf.beende();
    return super.close();
  }
}
