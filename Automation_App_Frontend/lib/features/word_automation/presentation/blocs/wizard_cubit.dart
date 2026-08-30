import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'wizard_state.dart';

@injectable
class WizardCubit extends Cubit<WizardState> {
  final UseCase<FormTemplate, UpdateFormTemplateParams> _updateFormTemplate;
  final UseCase<List<Mandant>, NoParams> _getMandanten;

  /// Ablage des Entwurfs. Der app-weite Speicher statt des Repositorys direkt:
  /// Sonst hielte seine Liste weiter den Vorgang **ohne** den gerade
  /// gesicherten Stand, und der nächste Einstieg böte einen veralteten an.
  final VorgangCubit _vorgaenge;

  Timer? _sicherung;

  /// Ob der aktuelle Stand bereits **bestätigt** ist (ein Dokument daraus
  /// erzeugt). Dann wird nichts mehr als Entwurf abgelegt: Der Rückfluss hat
  /// ihn im selben Atemzug am Vorgang gelöscht, und eine Sicherung danach
  /// brächte ihn als Angebot zurück, das nichts Neues enthält. Jede weitere
  /// Eingabe hebt die Marke wieder auf.
  bool _standIstBestaetigt = false;

  /// Wie lange nach der letzten Änderung gewartet wird, bevor der Entwurf zum
  /// Dienst geht. Das Formular meldet seinen Tippstand bereits entprellt; hier
  /// bündelt der Takt zusätzlich die Schadenspositionen, die bei jedem Zeichen
  /// melden.
  static const entwurfVerzoegerung = Duration(seconds: 2);

  WizardCubit(this._updateFormTemplate, this._getMandanten, this._vorgaenge)
    : super(const WizardState());

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
    _sicherung?.cancel();
    emit(
      state.copyWith(
        selectedVorgang: () => vorgang,
        selectedMandant: () => null,
        damageListing: () => null,
        schadenspositionFehler: const [],
        formDataEntwurf: () => null,
        entwurfAngebot: () => vorgang?.entwurf,
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
    _standIstBestaetigt = true;
    emit(state.copyWith(selectedVorgang: () => vorgang));
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

  /// Legt den angefangenen Stand sofort am Vorgang ab. Ohne gewählten Vorgang
  /// fehlt der Ablageort — freie Erfassung hält keinen Entwurf (bewusste
  /// Abgrenzung des ersten Wurfs).
  void sichereEntwurfJetzt() {
    _sicherung?.cancel();
    final referenz = state.selectedVorgang?.referenz;
    final werte = state.formDataEntwurf;
    if (referenz == null || werte == null || _standIstBestaetigt) return;

    final entwurf = VorgangEntwurf(
      gespeichertAm: DateTime.now(),
      feldWerte: werte,
      schadensaufstellung: state.damageListing,
    );
    if (entwurf.istLeer) return;
    _vorgaenge.sichereEntwurf(referenz, entwurf);
  }

  void _planeSicherung() {
    _standIstBestaetigt = false;
    _sicherung?.cancel();
    // Ohne Vorgang gibt es keinen Ablageort — dann braucht es auch keinen Takt.
    // (Und kein Widget-Test der freien Erfassung endet mit einem laufenden
    // Zeitgeber, den er nicht bestellt hat.)
    if (state.selectedVorgang == null) return;
    _sicherung = Timer(entwurfVerzoegerung, sichereEntwurfJetzt);
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
    _sicherung?.cancel();
    return super.close();
  }
}
