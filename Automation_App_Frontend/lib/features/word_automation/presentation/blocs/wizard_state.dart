part of 'wizard_cubit.dart';

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
  /// ([WizardCubit.setDamageListing]): Die Beanstandungen betreffen auch Zeilen,
  /// die es nicht in die Aufstellung schaffen, lassen sich also nicht aus ihr
  /// ableiten.
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

  /// Ein am gewählten Vorgang gefundener, noch **nicht angenommener** Entwurf.
  /// Solange er hier steht, zeigt der Ausfüllschritt die Leiste „Angefangener
  /// Stand von … — Weiterarbeiten / Verwerfen". Kein stilles Wiederherstellen:
  /// Der Anwalt entscheidet, ob die Werte in sein Schreiben kommen.
  final VorgangEntwurf? entwurfAngebot;

  /// Zähler, der einen Neuaufbau des Ausfüll-Formulars erzwingt. Nötig, wenn
  /// sich nur die **einzusetzenden Werte** geändert haben (übernommener
  /// Entwurf): Die FormGroup hängt sonst an Vorlage und Vorbelegung, und beide
  /// sind dabei unverändert — das Formular zeigte also weiter die alten Werte.
  final int aufbauMarke;

  /// Der Vorgang, aus dem das Schreiben erstellt wird (Phase 4). Liefert die
  /// Vorbelegung (Mandant + Antwort + Rechtsgebiet) und nimmt nach der
  /// Erzeugung Dokumentpfad und Status entgegen. Null = freie Erfassung ohne
  /// Vorgangsbezug.
  final Vorgang? selectedVorgang;

  /// Der zum [selectedVorgang] aufgelöste Registereintrag (für die
  /// Mandanten-Vorbelegung). Null, solange nicht aufgelöst oder kein Mandant
  /// verknüpft ist.
  final Mandant? selectedMandant;

  /// Ob das nächste Schreiben ein **neues** ist (§4.9) — im Gegensatz zur
  /// Korrektur des gespeicherten, die dessen Nummer behält und seine Fassung
  /// ersetzt. Der Anwalt entscheidet das in der Leiste des Ausfüllschritts;
  /// geraten wird es nicht.
  ///
  /// **Null heißt: noch nicht gewählt** (#133). Vorbelegt ist nichts — eine
  /// überlesene Vorauswahl „Korrektur" überschriebe das Schreiben, das schon in
  /// der Akte liegt. Solange ein gespeichertes Schreiben existiert und hier
  /// nichts steht, sagt der Ausfüllschritt vor dem Erstellen, was fehlt.
  ///
  /// Die Wahl gilt bis zum **Speichern**, nicht bis zum Erzeugen: Mehrfaches
  /// Erzeugen zwischendurch ändert nichts, erst der Speicherschritt verbraucht
  /// sie ([vermerkeGespeichertesSchreiben] setzt sie auf null zurück). Ohne
  /// gespeichertes Schreiben ohne Wirkung: dort ist die Nummer die 1.
  final bool? neuesSchreiben;

  const WizardState({
    this.currentStep = WizardStep.fillOut,
    this.selectedFormTemplate,
    this.damageListing,
    this.schadenspositionFehler = const [],
    this.mitAuflistung = false,
    this.vorsteuerabzugsberechtigt = true,
    this.formData,
    this.formDataEntwurf,
    this.entwurfAngebot,
    this.aufbauMarke = 0,
    this.selectedVorgang,
    this.selectedMandant,
    this.neuesSchreiben,
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
    VorgangEntwurf? Function()? entwurfAngebot,
    int? aufbauMarke,
    Vorgang? Function()? selectedVorgang,
    Mandant? Function()? selectedMandant,
    bool? Function()? neuesSchreiben,
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
      entwurfAngebot: entwurfAngebot != null
          ? entwurfAngebot()
          : this.entwurfAngebot,
      aufbauMarke: aufbauMarke ?? this.aufbauMarke,
      selectedVorgang: selectedVorgang != null
          ? selectedVorgang()
          : this.selectedVorgang,
      selectedMandant: selectedMandant != null
          ? selectedMandant()
          : this.selectedMandant,
      neuesSchreiben: neuesSchreiben != null
          ? neuesSchreiben()
          : this.neuesSchreiben,
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
    entwurfAngebot,
    aufbauMarke,
    selectedVorgang,
    selectedMandant,
    neuesSchreiben,
  ];
}
