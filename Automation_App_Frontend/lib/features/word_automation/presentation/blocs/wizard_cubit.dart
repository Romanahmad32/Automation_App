import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Schritte des Ausfüll-Wizards. Der Schritt [schadensaufstellung] existiert
/// nur, wenn der Nutzer "mit Auflistung" gewählt hat (siehe [WizardState.steps]);
/// die Enum-Indizes sind zugleich die festen Positionen im IndexedStack der Seite.
enum WizardStep { fillOut, schadensaufstellung, review, save }

/// Reine UI-Orchestrierung des Wizards:
/// Vorlage wählen & ausfüllen → (Schadensaufstellung) → Begutachten → Speichern.
/// Die eigentliche Arbeit (Dateiauswahl, Generierung, PDF) bleibt in den
/// bestehenden Blocs; hier liegen aktueller Schritt und gesammelte Eingaben.
class WizardState extends Equatable {
  final WizardStep currentStep;
  final FormTemplate? selectedFormTemplate;
  final DamageListing? damageListing;

  /// Was das Schadensaufstellungs-Formular an seinen Zeilen beanstandet — je
  /// Eintrag ein fertiger Satz. Leer = nichts zu beanstanden.
  ///
  /// Steht hier und nicht im Formular, weil der Schritt daran den Knopf
  /// „Dokument erstellen" sperrt. Wird **zusammen** mit [damageListing] gesetzt
  /// ([setDamageListing]): Die Beanstandungen betreffen auch Zeilen, die es
  /// nicht in die Aufstellung schaffen, lassen sich also nicht aus ihr ableiten.
  final List<String> schadenspositionFehler;

  /// Ob der Nutzer die Version **mit** Auflistung (Schadensaufstellung) gewählt
  /// hat. Nur möglich, wenn die Vorlage eine entsprechende Datei hinterlegt hat.
  /// Steuert die geladene Word-Datei und die sichtbaren Wizard-Schritte.
  final bool mitAuflistung;

  /// Ob der Mandant vorsteuerabzugsberechtigt ist. Steuert sowohl das
  /// Ankreuzen im Dokument ("☒ ist / ☐ ist nicht vorsteuerabzugsberechtigt")
  /// als auch die RVG-Umsatzsteuer (`applyVat = !vorsteuerabzugsberechtigt`).
  final bool vorsteuerabzugsberechtigt;

  /// **Abgesendete** Formularfelder aus dem ersten Schritt. Wird dort
  /// zwischengespeichert, weil die Dokumenterzeugung bei "mit Auflistung" erst
  /// am Ende des Schadensaufstellungs-Schritts läuft.
  final Map<String, String>? formData;

  /// Der laufende Tippstand desselben Formulars — im Unterschied zu [formData]
  /// **nicht** bestätigt. Wird entprellt mitgeschrieben, damit ein Neuaufbau
  /// des Formulars die Eingaben wieder einsetzen kann (die Vorlage wurde
  /// nebenan bearbeitet, die Liste neu geladen).
  ///
  /// Getrennt gehalten, weil [formData] auch eine Freigabe ist: An ihm hängen
  /// `WizardStepBar._isEnabled` und der Erzeugen-Knopf des
  /// Schadensaufstellungs-Schritts. Schriebe der Tippstand dorthin, schaltete
  /// das erste getippte Zeichen den nächsten Schritt frei.
  final Map<String, String>? formDataEntwurf;

  /// Der Vorgang, aus dem das Schreiben erstellt wird (Phase 4). Liefert die
  /// Vorbelegung (Mandant + Antwort + Rechtsgebiet) und nimmt nach der
  /// Erzeugung Dokumentpfad und Status entgegen. Null = freie Erfassung ohne
  /// Vorgangsbezug.
  final Vorgang? selectedVorgang;

  /// Der zum [selectedVorgang] aufgelöste Registereintrag (für die
  /// Mandanten-Vorbelegung). Null, solange nicht aufgelöst oder kein Mandant
  /// verknüpft ist.
  final Mandant? selectedMandant;

  const WizardState({
    this.currentStep = WizardStep.fillOut,
    this.selectedFormTemplate,
    this.damageListing,
    this.schadenspositionFehler = const [],
    this.mitAuflistung = false,
    this.vorsteuerabzugsberechtigt = true,
    this.formData,
    this.formDataEntwurf,
    this.selectedVorgang,
    this.selectedMandant,
  });

  /// Ob aus der erfassten Schadensaufstellung ein Dokument entstehen darf:
  /// mindestens eine Position, und keine Zeile beanstandet.
  ///
  /// Ein einziger Ausdruck statt zweier Bedingungen im Schritt — die musste
  /// jemand von Hand gleichlaufend halten, und „hat Positionen" behauptete dabei
  /// eine Gültigkeit, die es nicht prüfte.
  bool get schadensaufstellungIstErzeugbar =>
      (damageListing?.items.isNotEmpty ?? false) &&
      schadenspositionFehler.isEmpty;

  /// Pfad der aktuell relevanten Word-Datei (je nach [mitAuflistung]).
  String? get activeWordFilePath => mitAuflistung
      ? selectedFormTemplate?.wordFilePathMitAuflistung
      : selectedFormTemplate?.wordFilePathOhneAuflistung;

  /// Die für die aktuelle Auswahl sichtbaren Schritte — Single Source of Truth
  /// für Schrittleiste und Navigation.
  List<WizardStep> get steps => mitAuflistung
      ? WizardStep.values
      : const [WizardStep.fillOut, WizardStep.review, WizardStep.save];

  WizardState copyWith({
    WizardStep? currentStep,
    FormTemplate? Function()? selectedFormTemplate,
    DamageListing? Function()? damageListing,
    List<String>? schadenspositionFehler,
    bool? mitAuflistung,
    bool? vorsteuerabzugsberechtigt,
    Map<String, String>? Function()? formData,
    Map<String, String>? Function()? formDataEntwurf,
    Vorgang? Function()? selectedVorgang,
    Mandant? Function()? selectedMandant,
  }) {
    return WizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedFormTemplate: selectedFormTemplate != null
          ? selectedFormTemplate()
          : this.selectedFormTemplate,
      damageListing: damageListing != null
          ? damageListing()
          : this.damageListing,
      schadenspositionFehler:
          schadenspositionFehler ?? this.schadenspositionFehler,
      mitAuflistung: mitAuflistung ?? this.mitAuflistung,
      vorsteuerabzugsberechtigt:
          vorsteuerabzugsberechtigt ?? this.vorsteuerabzugsberechtigt,
      formData: formData != null ? formData() : this.formData,
      formDataEntwurf: formDataEntwurf != null
          ? formDataEntwurf()
          : this.formDataEntwurf,
      selectedVorgang: selectedVorgang != null
          ? selectedVorgang()
          : this.selectedVorgang,
      selectedMandant: selectedMandant != null
          ? selectedMandant()
          : this.selectedMandant,
    );
  }

  @override
  List<Object?> get props => [
    currentStep,
    selectedFormTemplate,
    damageListing,
    schadenspositionFehler,
    mitAuflistung,
    vorsteuerabzugsberechtigt,
    formData,
    formDataEntwurf,
    selectedVorgang,
    selectedMandant,
  ];
}

@injectable
class WizardCubit extends Cubit<WizardState> {
  final UseCase<FormTemplate, UpdateFormTemplateParams> _updateFormTemplate;
  final UseCase<List<Mandant>, NoParams> _getMandanten;

  WizardCubit(this._updateFormTemplate, this._getMandanten)
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
  /// des neuen.
  Future<void> selectVorgang(Vorgang? vorgang) async {
    emit(
      state.copyWith(
        selectedVorgang: () => vorgang,
        selectedMandant: () => null,
        damageListing: () => null,
        schadenspositionFehler: const [],
        formDataEntwurf: () => null,
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
    emit(state.copyWith(selectedVorgang: () => vorgang));
  }

  void goToStep(WizardStep step) {
    if (!state.steps.contains(step)) {
      return;
    }
    emit(state.copyWith(currentStep: step));
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
  }

  /// Schreibt den laufenden Tippstand mit (entprellt aus dem Formular). Gibt
  /// **keine** Freigabe: Dafür ist [setFormData] zuständig.
  void setFormDataEntwurf(Map<String, String> werte) {
    emit(state.copyWith(formDataEntwurf: () => werte));
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
}
