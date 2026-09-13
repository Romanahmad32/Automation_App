import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/entwurf_sicherung_steuerung.dart';
import 'package:automation_app/features/word_automation/presentation/utils/feld_stand.dart';
import 'package:automation_app/features/word_automation/presentation/utils/vorlagen_fassung.dart';
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

  /// Die Ablage des angefangenen Stands — Bestätigt-Marke und der Weg zum
  /// Vorgang liegen dort, nicht hier.
  final EntwurfSicherungSteuerung _entwurf;

  WizardCubit(
    this._updateFormTemplate,
    this._getMandanten,
    VorgangCubit vorgaenge,
  ) : _entwurf = EntwurfSicherungSteuerung(vorgaenge),
      super(const WizardState());

  /// Wählt den Vorgang, aus dem das Schreiben erstellt wird. Die Auswahl wird
  /// sofort übernommen (die Vorbelegung reagiert), der verknüpfte Mandant aus
  /// dem Register danach asynchron nachgeladen — die Antwortdaten stecken schon
  /// im Vorgang, die Mandanten-Stammdaten ergänzen Name und Anschrift.
  ///
  /// Die Schadensaufstellung des vorigen Vorgangs fällt dabei weg — sie gehört
  /// dorthin, und blieb sie stehen, zeigte der nächste Vorgang die Positionen
  /// des vorigen. An ihre Stelle tritt die des **neuen** Vorgangs, soweit sein
  /// angefangener Stand eine trägt; hat er keine, bleibt `null`, und der
  /// Listener des Schadensaufstellungs-Schritts lädt die gespeicherte nach (er
  /// greift nur bei `damageListing == null`).
  ///
  /// Der Tippstand wird **ausgetauscht**, nicht geleert: Der des vorigen
  /// Vorgangs geht, der am neuen liegende kommt — ohne Nachfrage (#133). Das
  /// Formular zeigt dann Vorbelegung und diese Werte gemischt; weil der Entwurf
  /// nur die Abweichungen trägt, verdeckt er keine frische Vorbelegung. Wer
  /// zwischen zwei Vorgängen hin- und herspringt, findet an jedem wieder vor,
  /// was er dort zuletzt getippt hat.
  ///
  /// **Derselbe Vorgang noch einmal ist keine Wahl** (#133): Der Absprung aus
  /// Übersicht oder Vorgängen wählt den bereits gewählten erneut. Vorher leerte
  /// das den Tippstand — sichtbar geschah nichts, denn die FormGroup hängt an
  /// Vorlage und Vorbelegung und blieb stehen; der Stand war trotzdem weg.
  /// Verglichen wird die **Vorgangsreferenz**, nicht die
  /// Objektidentität: `vorgang_selector.dart` reicht Vorgänge aus der geladenen
  /// Liste und aus dem Vorauswahl-Vorschlag durch, und nach jedem Neuladen sind
  /// das neue Instanzen derselben Sache — mit `identical` wäre jede davon
  /// wieder ein voller Reset. Ein inhaltlich geänderter Vorgang derselben
  /// Referenz ist kein Wechsel, sondern ein neuer Stand und geht weiter über
  /// [uebernehmeVorgangsStand].
  Future<void> selectVorgang(Vorgang? vorgang) async {
    final alt = state.selectedVorgang?.referenz;
    final neu = vorgang?.referenz;
    if (alt != null && neu != null && Vorgang.gleicheReferenz(alt, neu)) {
      // Kein Wechsel, aber ein neuer Stand derselben Sache (z. B. Zentralruf-
      // Antwort eingetroffen, #150): Die Anzeige bekommt die frischen Daten,
      // sonst wird nichts angerührt — insbesondere bleibt der Tippstand stehen,
      // statt durch den am Vorgang liegenden (womöglich älteren) ersetzt zu
      // werden. Deshalb der minimale eigene Emit.
      emit(state.copyWith(selectedVorgang: () => vorgang));
      return;
    }
    final entwurf = vorgang?.entwurf;
    emit(
      state.copyWith(
        selectedVorgang: () => vorgang,
        selectedMandant: () => null,
        schadenspositionFehler: const [],
        // Der angefangene Stand des neuen Vorgangs, still eingesetzt (#133).
        // Beides zusammen, weil beides zusammen gesichert wurde: Felder ohne
        // die Positionen wären ein halber Stand.
        formDataEntwurf: () => entwurf?.feldWerte,
        damageListing: () => entwurf?.schadensaufstellung,
        // Vorlage und Vorbelegung ändern sich mit dem Vorgang, der Schlüssel der
        // FormGroup also meistens ohnehin — aber eben nur meistens. Die Marke
        // macht aus „meistens" ein „immer".
        aufbauMarke: state.aufbauMarke + 1,
        // Die Entscheidung gehört dem Vorgang, aus dem sie stammt: Am neuen
        // steht eine andere Nummer, und „neues Schreiben" hiesse dort etwas
        // anderes als hier. Zurück auf „noch nicht gewählt", nicht auf
        // „Korrektur" — geraten wird nicht (#133).
        neuesSchreiben: () => null,
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

  /// Wirft die eigenen Eingaben weg und lässt wieder die Vorbelegung gelten —
  /// der Weg zurück, den der stille Wiedereinstieg braucht (#133): Wer seinen
  /// angefangenen Stand nicht mehr will, bekäme ihn sonst bei jeder Rückkehr
  /// wieder vorgesetzt.
  ///
  /// Gelöscht wird auch am Vorgang, sonst stünde er beim nächsten Einstieg
  /// wieder da. Weil das der einzige Griff ist, der Getipptes **wegwirft**,
  /// gibt er es zurück: Die Meldung darüber bietet es über
  /// [stelleEingabenWiederHer] an, solange sie steht.
  ///
  /// Die Schadensaufstellung bleibt unberührt — der Knopf steht über dem
  /// Ausfüll**formular** und meint dessen Felder. Sie liegt in einem eigenen
  /// Schritt mit eigenen Griffen.
  Map<String, String>? setzeEingabenZurueck() {
    final bisher = state.formDataEntwurf;
    emit(EntwurfSicherungSteuerung.nachZuruecksetzen(state));
    _entwurf.nachEingabe(state);
    return (bisher == null || bisher.isEmpty) ? null : bisher;
  }

  /// Nimmt ein [setzeEingabenZurueck] zurück: Die Eingaben stehen wieder im
  /// Formular und wieder am Vorgang.
  void stelleEingabenWiederHer(Map<String, String> werte) {
    emit(EntwurfSicherungSteuerung.nachWiederherstellung(state, werte));
    _entwurf.nachEingabe(state);
  }

  /// Ersetzt den gewählten Vorgang durch seinen aktualisierten Stand (z. B.
  /// nach dem Rückfluss der Wizard-Eingaben in den Vorgang), ohne den
  /// Mandanten neu zu laden. No-op, wenn inzwischen ein anderer Vorgang
  /// gewählt wurde.
  void uebernehmeVorgangsStand(Vorgang vorgang) {
    if (!_entwurf.passtZuAktuellemVorgang(state, vorgang.referenz)) return;
    _entwurf.markiereBestaetigt();
    // Die Wahl „Korrektur oder neues Schreiben" bleibt stehen: Sie gilt bis zum
    // **Speichern**, nicht bis zum Erzeugen (#133). Wer dreimal erzeugt und
    // einmal ablegt, hat ein Schreiben — und weil das Erzeugen die Nummer nicht
    // mehr fortschreibt, liefert jeder dieser Durchgänge dieselbe.
    emit(state.copyWith(selectedVorgang: () => vorgang));
  }

  /// Die Entscheidung des Anwalts, ob das nächste Schreiben ein **neues** ist
  /// oder die Korrektur des gespeicherten (§4.9). Gestellt wird sie in der
  /// Leiste des Ausfüllschritts, und nur solange ein Schreiben gespeichert ist
  /// — vorher gibt es nichts zu entscheiden.
  ///
  /// `null` heißt „wieder offen": So setzt der Speicherschritt die verbrauchte
  /// Wahl zurück ([vermerkeGespeichertesSchreiben]), statt sie stillschweigend
  /// auf „Korrektur" fallen zu lassen.
  void setNeuesSchreiben(bool? neuesSchreiben) {
    emit(state.copyWith(neuesSchreiben: () => neuesSchreiben));
  }

  void goToStep(WizardStep step) {
    if (!state.steps.contains(step)) {
      return;
    }
    emit(state.copyWith(currentStep: step));
    // Einen Eingabeschritt zu verlassen ist der Punkt, an dem der Anwalt mit
    // dem Bisherigen fertig ist — hier wird nicht auf die Entprellung des
    // Formulars gewartet. Der Sprung ins Begutachten ist keiner: Dorthin kommt
    // man nur über ein erzeugtes Dokument, und dann ist der Stand bestätigt
    // statt angefangen.
    if (step == WizardStep.fillOut || step == WizardStep.schadensaufstellung) {
      sichereEntwurfJetzt();
    }
  }

  /// Setzt die gewählte Vorlage — und unterscheidet dabei zwei Fälle, die
  /// vorher denselben Weg gingen:
  ///
  /// **Wechsel** (andere Vorlage, oder gar keine mehr): Der abgesendete Stand
  /// und die Schadensaufstellung gehören zur vorherigen Vorlage und fallen weg.
  /// Der **angefangene** Stand bleibt: Er ist nach Feldbezeichnung geschlüsselt,
  /// nicht nach Vorlage, und wer zwischen zwei Vorlagen hin- und herschaut, will
  /// beim Zurückkommen sein Getipptes wiederfinden (#133). Was die neue Vorlage
  /// nicht kennt, zeigt sie nicht an — verloren ist es deshalb nicht.
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
        VorlagenFassung.mitGueltigemSchritt(
          state.copyWith(
            selectedFormTemplate: () => template,
            mitAuflistung: VorlagenFassung.fuer(
              template,
              bisher: state.mitAuflistung,
            ),
          ),
        ),
      );
      return;
    }

    emit(
      VorlagenFassung.mitGueltigemSchritt(
        state.copyWith(
          selectedFormTemplate: () => template,
          mitAuflistung:
              template != null && VorlagenFassung.fuer(template, bisher: false),
          vorsteuerabzugsberechtigt: true,
          damageListing: () => null,
          schadenspositionFehler: const [],
          formData: () => null,
        ),
      ),
    );
  }

  /// Schaltet zwischen Version ohne/mit Auflistung um. Eingaben des
  /// Schadensaufstellungs-Schritts werden beim Wechsel verworfen.
  void setMitAuflistung(bool mitAuflistung) {
    emit(
      VorlagenFassung.mitGueltigemSchritt(
        state.copyWith(
          mitAuflistung: mitAuflistung,
          damageListing: () => null,
          schadenspositionFehler: const [],
        ),
      ),
    );
  }

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
    _entwurf.nachEingabe(state);
  }

  /// Übernimmt den **abgesendeten** Stand des Ausfüll-Formulars. Der angefangene
  /// Stand zieht mit, damit ein späterer Neuaufbau nicht auf ein älteres
  /// Getipptes zurückfällt.
  void setFormData(
    Map<String, String>? formData, {
    Map<String, String> vorbelegung = const {},
  }) {
    final stand = formData == null
        ? state.formDataEntwurf
        : _mitAbweichungen(formData, vorbelegung);
    emit(
      state.copyWith(formData: () => formData, formDataEntwurf: () => stand),
    );
    _entwurf.nachEingabe(state);
  }

  /// Schreibt den laufenden Tippstand mit (entprellt aus dem Formular) und legt
  /// ihn sofort am Vorgang ab. Gibt **keine** Freigabe: Dafür ist [setFormData]
  /// zuständig.
  ///
  /// [werte] ist der **vollständige** Formularstand, [vorbelegung] das, was das
  /// Formular ohne ihn zeigen würde; aufgehoben wird nur der Unterschied
  /// ([EntwurfAbweichung.nurAbweichende]). Ohne [vorbelegung] gilt alles als
  /// abweichend — der Weg der freien Erfassung, die keine Vorbelegung hat.
  ///
  /// [fuerReferenz] ist die Referenz des Vorgangs, für den das meldende
  /// Formular gebaut wurde — der Aufrufer bindet sie beim Bauen ein, nicht
  /// erst hier ([AusfuellFormular]). Weicht sie von [WizardState.selectedVorgang]
  /// ab, wird die Meldung verworfen ([EntwurfSicherungSteuerung.passtZuAktuellemVorgang]):
  /// Der `FormWertBeobachter` des alten Formulars meldet aus seinem
  /// `dispose()` heraus manchmal erst **nach** einem Vorgangswechsel, und ohne
  /// diesen Abgleich schriebe sie die Werte des alten Vorgangs auf den neuen
  /// fort (Review-Nachbesserung #133).
  void setFormDataEntwurf(
    Map<String, String> werte, {
    Map<String, String> vorbelegung = const {},
    required String? fuerReferenz,
  }) {
    if (!_entwurf.passtZuAktuellemVorgang(state, fuerReferenz)) return;
    final stand = _mitAbweichungen(werte, vorbelegung);
    emit(state.copyWith(formDataEntwurf: () => stand));
    _entwurf.nachEingabe(state);
  }

  /// Der bisherige Stand, überschrieben mit den Abweichungen aus [werte] —
  /// siehe [EntwurfSicherungSteuerung.zusammengefuehrt].
  Map<String, String> _mitAbweichungen(
    Map<String, String> werte,
    Map<String, String> vorbelegung,
  ) => EntwurfSicherungSteuerung.zusammengefuehrt(
    bisher: state.formDataEntwurf,
    werte: werte,
    vorbelegung: vorbelegung,
  );

  /// Legt den angefangenen Stand sofort am Vorgang ab (Einzelheiten und
  /// Abbruchgründe in [EntwurfSicherungSteuerung.sichereJetzt]).
  void sichereEntwurfJetzt() => _entwurf.sichereJetzt(state);

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
  /// letzten 300 ms, die die Entprellung des Formulars kostet. Der Empfänger
  /// ([VorgangCubit]) lebt weiter, seine Ablage läuft also auch dann noch, wenn
  /// dieser Cubit schon geschlossen ist.
  @override
  Future<void> close() {
    sichereEntwurfJetzt();
    return super.close();
  }
}
