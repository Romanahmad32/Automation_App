# word_automation — Fallstricke

Der lange Rest zu `FEATURE.md`. Der Steckbrief hat ein Zeilenbudget, diese Datei nicht. Was man
**vor** dem ersten Griff kennen muss — Schrittfolge, Arbeitsordner, Zeitgrenzen — steht weiter
im Steckbrief; hier steht, was einen beim zweiten Griff erwischt. Dieses Feature ist mit rund
sechzig Dateien das größte der App, entsprechend viel davon.

## Ablage in der Akte

- Der Anwalt wählt im Speicherschritt das `AblageFormat` (Word, PDF, beide) — für die Akte und
  für das Speichern anderswo getrennt. Für die Akte entsteht das PDF neben der Word-Datei
  (`starteAblage` in `utils/ablage_durchfuehrung.dart`), beim freien Speichern direkt am Ziel
  (`utils/dokument_export.dart`). **Ohne Word-Fassung in der Akte entfallen Umschwenken und
  Aufräumen** — sonst wäre die bearbeitbare Fassung weg.
- `EditedDocumentLoaded.inAkteAbgelegt` trennt „abgelegt" von „erzeugt": nur ohne die Marke
  springt der Listener der Page ins Begutachten. Wer sie vergisst, wirft den Anwalt nach jeder
  Ablage aus Schritt 3.

## Vorgang und Berechnung

- Der Vorgangsstatus wird nur vorwärts geschaltet (`status.index`): „erstellt" im Listener der
  Page, „abgelegt" in `schliesseAblageAb`, „versendet" über `VorgangCubit.abschliessen`. Vorher
  immer `findeZuReferenz`.
- Die Vorsteuer-Checkbox steht in zwei gleichzeitig gemounteten Schritten auf demselben
  Cubit-Feld (`applyVat == !vorsteuerabzugsberechtigt`); ein Listener rechnet die RVG-Kosten neu,
  die Änderung ist dialogbestätigt.
- **Eine Schadensposition über `0,00 €` ist gültig** (noch nicht beziffert), ein negativer Betrag
  nicht. Geprüft wird im Formular an der Zeile (`utils/schadenspositionen_pruefung.dart`), nicht
  erst im Dienst: dessen `[Range]` antwortet mit einem HTTP 400, das keine Zeile benennt.
- **Das Verdikt kommt aus dem Formular, nicht aus der `DamageListing`.** `DamageListingForm.onChanged`
  meldet Stand **und** Beanstandungen; `WizardState.schadenspositionFehler` hält sie, und
  `schadensaufstellungIstErzeugbar` ist die einzige Stelle, die über den Knopf entscheidet. Der
  Grund: Eine Zeile ohne Bezeichnung wandert nicht in die Aufstellung. Wer die Beanstandungen aus
  ihr ableitet, übersieht genau die Zeile mit `-250` und leerer Bezeichnung — Feld rot, Knopf frei.
- **Die Standardpositionen (§4.4) gehören diesem Feature, ihr Editor hängt aber in den
  Einstellungen**: `StandardpositionenSettingsView` (Reiter „Schadensaufstellung") wird von
  `settings_page.dart` nur eingehängt — wie die Reiter aus `mailbox` und `backup`. Der
  `StandardpositionenCubit` ist `@injectable`, also je Seite eine eigene Instanz: Eine Änderung in
  den Einstellungen erreicht eine bereits offene Word-Automation-Seite nicht. Im Wizard kippt der
  `ValueKey` des `DamageListingForm` genau einmal von `false` auf `true`, wenn die konfigurierten
  Positionen eintreffen — der Schritt ist im `IndexedStack` von Anfang an aufgebaut, ohne den
  Neuaufbau bliebe die Vorgabe aus dem Code stehen. Im selben Reiter liegt auch die
  Titelzeilen-Farbe der Tabelle (`TabellenkopfFarbeField` aus `settings`): Sie speichert **sofort
  beim Auswählen** für sich (`SaveTabellenkopfFarbeEvent`, auf dem geladenen Stand), und die
  Vorschau folgt dem Farbfeld live — auch einem noch ungespeicherten Wert.
- Die Geldgrenzen der Backend-DTOs (`DamageItemDto.Amount`, `RvgCalculationRequestDto.Gegenstandswert`)
  brauchen ihre **Nachkommastellen**: `[Range(0, …)]` bindet `RangeAttribute(int, int)`, rundet den
  Betrag vor dem Vergleich und lässt `-0,49` durch; jenseits von `int.MaxValue` wird aus 400 ein 500.
  `RangeUeberladungTests` hält das fest.
- Ein Gegenstandswert von `0` **mit** Positionen ist rechenbar und ergibt die unterste
  Wertgebührenstufe (51,50 €); `0` **ohne** Positionen ist der Reset. Beides unterscheidet allein
  `CalculateRvgEvent.hatPositionen` — der leere Stand muss beim Bloc ankommen, sonst bleibt der
  zuletzt berechnete Betrag in der Vorschau stehen und eine laufende Anfrage unstorniert.

## Vorlagen

- `linkWordFileToTemplate` merkt sich die gewählte .docx am aktiven Vorlagen-Slot; die
  Vorlagenliste nur bei echter Neuverknüpfung neu laden, sonst setzt das Resync im
  `TemplateSelector` die Auswahl zurück.
- **`selectFormTemplate` bekommt zwei verschiedene Dinge auf demselben Weg gemeldet.** Der
  `TemplateSelector` gleicht die Auswahl per Wert mit der neu geladenen Liste ab und meldet jede
  andernorts *bearbeitete* Vorlage als Auswahl — gleiche ID, neuer Stand. Nur ein Wechsel der ID
  (oder `null` = gelöscht) verwirft den Eingabestand; eine Aktualisierung behält Eingaben,
  Aufstellung, Fassung und Schritt. Vorher kostete ein umgestellter Haken in der Vorlage alles,
  inklusive des Schritts: `mitAuflistung` fiel auf die Vorgabe zurück und nahm die
  Schadensaufstellung aus `steps`.
- **`formData` ist die Freigabe, `formDataEntwurf` der Tippstand.** An `formData` hängen
  `WizardStepBar._isEnabled` und der Erzeugen-Knopf des Schadensaufstellungs-Schritts, es entsteht
  also erst beim Absenden. Der laufend mitgeschriebene Stand (`FormWertBeobachter`, 2 s entprellt)
  gehört deshalb in das zweite Feld — im ersten schaltete das erste getippte Zeichen den nächsten
  Schritt frei. Beim Vorgangswechsel fällt der Entwurf weg, sonst schlüge er die Vorbelegung des
  neuen Vorgangs.
- **Der angefangene Stand liegt am Vorgang, nicht im Wizard.** `WizardCubit` sichert ihn entprellt
  (2 s), beim Wechsel zwischen den Eingabeschritten und beim Schließen der Seite über
  `VorgangCubit.sichereEntwurf` → `PUT api/Vorgaenge/entwurf`. Bewusst **nicht** über den Upsert des
  ganzen Vorgangs: Der schickte bei jedem Takt den Vorgang aus der Sicht des Wizards mit und
  überschriebe eine inzwischen eingetroffene Zentralruf-Antwort. Nach der Erzeugung wird nicht mehr
  gesichert (`_standIstBestaetigt`) — sonst käme der gerade bestätigte Stand als Angebot zurück,
  während der Rückfluss ihn im selben Atemzug löscht.
- **Der Entwurf wird angeboten, nie eingesetzt.** `selectVorgang` legt ihn nach
  `WizardState.entwurfAngebot`, die Leiste (`EntwurfHinweis`) zeigt Zeitpunkt und beide Wege. Erst
  „Weiterarbeiten" schreibt die Werte in `formDataEntwurf` — **und erhöht `aufbauMarke`**, sonst
  bliebe die FormGroup stehen (Vorlage und Vorbelegung sind ja unverändert) und der Anwalt sähe auf
  seinen Klick hin nichts geschehen. Ohne gewählten Vorgang gibt es keinen Ablageort: freie
  Erfassung hält keinen Entwurf.
- **Der Stift am Feld ändert die Vorlage, nicht nur die Anzeige.** `FeldEinstellungDialog` liefert
  ein geändertes `FieldData` ab, `WizardCubit.aktualisiereFeld` speichert es über `UpdateFormTemplate`.
  Der Dialog prüft den Namen nach derselben Regel wie der Dienst (`^[\p{L}\p{N} _-]+$`) und gegen die
  übrigen Feldnamen; zwei gleiche Namen wären in der `FormGroup` ein Feld. Gespeichert wird nur bei
  echter Änderung (`FieldData` vergleicht sich nicht selbst) — und nur dann lädt die Vorlagenliste
  neu, sonst setzt das Resync im `TemplateSelector` zurück.
- **Eine Feldänderung fasst immer auch den erfassten Stand an** (`utils/feld_stand.dart`), weil der
  nach Feldnamen geschlüsselt ist. Zwei Fälle, die sich leicht verwechseln lassen und beide still
  danebengehen:
  - **Umbenennung** → `FeldStand.umgeschluesselt`: Der Wert wandert auf den neuen Namen mit, sonst
    fände er sich nur unter einem, den die Vorlage nicht mehr kennt. Ein **leerer** Wert fällt dabei
    weg — er hat nichts zu bewahren, schlüge aber die Vorbelegung.
  - **Neue Datenquelle** → `FeldStand.ohneFeld`: Der Wert gibt den Platz frei, damit die Vorbelegung
    greift. Ohne das gibt es **keinen Weg zurück** zur Vorbelegung: Der `FormWertBeobachter` schreibt
    zwei Sekunden nach dem ersten Tastendruck *alle* Felder mit, auch die unangetasteten, und ab da
    beschattet der erfasste Stand die Vorbelegung dauerhaft. Geräumt wird nur, wenn die neue Quelle
    zum gewählten Vorgang **tatsächlich einen Wert hat** (`_weichtDerVorbelegung` fragt denselben
    `VorgangPrefillMatcher`, aus dem das Formular seine Vorbelegung zieht) — sonst nähme der Dialog
    die Eingabe weg und setzte nichts an ihre Stelle. Der verdrängte Wert kommt als
    `FeldAenderung.verdraengterWert` zurück und steht in der Meldung als „Alten Wert zurückholen"
    (`stelleFeldWertWiederHer`); zurückgeholt wird der **Wert**, nicht die Vorlagenänderung.
  In beiden Fällen gilt: `aufbauMarke` muss steigen, sobald der erfasste Stand geräumt wird. Setzt
  der Anwalt die Quelle auf das, was die Namens-Heuristik ohnehin erkannt hatte, ist die Vorbelegung
  Zeichen für Zeichen dieselbe — und nur sie steht im Schlüssel der `FormGroup`.
- **Die Hinweiszeile unter dem Feld braucht `helperMaxLines: 2`.** Die Spalte ist 450 px breit, der
  Stift nimmt ihr weitere ~48 px: „* Pflichtfeld · Vorbelegt aus dem letzten Schreiben" passt in
  keine Zeile, und mit der Material-Vorgabe wurde daraus ein „…". Aus demselben Grund sagt
  `PrefillQuelle.gespeichert` nur „aus dem letzten Schreiben"; den Zusatz „zu diesem Vorgang" trägt
  die Sammelzeile darüber (`VorgangsdatenHinweis`), die Platz hat.
- **Der Schlüssel der `FormGroup` trägt eine Feldsignatur** (`form_template_builder.dart`): Label,
  Typ und Pflichtangabe. Ohne sie überlebt die alte Gruppe eine bearbeitete Vorlage, und das
  Formular zeigt neue Felder über alten Controls — ein auf „nicht erforderlich" gestelltes Feld
  bleibt still Pflichtfeld, ein umbenanntes wirft `FormControlNotFoundException`. Der bereits
  getippte Stand (`erfassteWerte`) steht bewusst **nicht** im Schlüssel: sonst setzte sich das
  Formular beim Tippen selbst zurück.
