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
- **Ein Punkt im Betrag ist nur dann ein Tausendertrennzeichen, wenn er einer sein kann**
  (`utils/betrag_eingabe.dart`). Genau drei Ziffern dahinter und kein Komma daneben, das die
  Dezimalrolle schon vergeben hat — sonst ist er das Dezimaltrennzeichen. Die frühere Fassung
  strich jeden Punkt und machte aus `1.5` kommentarlos **15,00 €**: keine Meldung, kein negativer
  Betrag, plausible Vorschau, zehnfacher Betrag im Schreiben. Was danach mehrdeutig bleibt
  (`1.234.56`) oder Beiwerk trägt (`1.234,56 €`), wird **nicht geraten** — es bleibt unlesbar.
- **Unlesbar heißt markiert und gesperrt, nicht weggelassen.** Eine Zeile, deren Betrag sich nicht
  lesen ließ, fiel früher stillschweigend aus der Aufstellung — bei freiem Knopf. Beanstandet wird
  aber erst, wenn die Zeile *gemeint* ist: Bezeichnung vorhanden **und** etwas im Betragsfeld.
  Beides am Zustand festgemacht und nicht am Fokus, damit das Verdikt auch dann stimmt, wenn der
  Anwalt direkt aus dem Feld heraus auf „Dokument erstellen" klickt. Die vorbelegten
  Standardpositionen (Bezeichnung, leeres Betragsfeld) bleiben damit unbeanstandet.
- **Die drei Felder unter der Liste prüfen sich anders als die Zeilen darüber**
  (`utils/rvg_felder_pruefung.dart`). Sie werden am **Rohtext** geprüft, nicht am gelesenen Wert:
  Ihr *leerer* Zustand hat eine eigene Bedeutung (Gebührensatz → 1,3; Korrekturfelder →
  automatisch nach § 13 RVG), und die lässt sich an einer Zahl nicht mehr von einer getippten
  unterscheiden. Der *leere* Fall wird deshalb vor dem Lesen abgefangen und nicht am `null`
  danach: Leer und unlesbar ergeben beide `null` und bedeuten das Gegenteil voneinander.
  Unlesbares zählt in allen drei Feldern als Verstoß — der Rückfall (1,3 bzw. „automatisch") ist
  dem leeren Feld zugedacht und ging sonst still hinaus, obwohl etwas anderes im Feld stand. `0`
  im Gebührensatz ist der schärfste Fall, weil sie *lesbar* ist und der Rückfall deshalb erst
  recht nicht griff. Ein unlesbarer Zwischenstand beim Tippen entsteht dabei nicht: `1`, `1,`
  und `1,3` lesen sich alle.
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
- **Die Felder der anderen Vorlagenfassung werden eingeklappt, nicht entfernt** (#82,
  `VerwendeteFelder` + `NichtVerwendeteFelder`). Eine Vorlage hat zwei Word-Dateien, aber eine
  Feldliste; was nur in der anderen Datei als `{{Platzhalter}}` steht, verwirft die Ersetzung
  wortlos. Die Controls müssen trotzdem in der `FormGroup` bleiben: `onWerteGeaendert` schreibt
  `formGroup.value` in den Entwurf, ein fehlendes Feld fiele beim nächsten Tastendruck heraus —
  und wer HGN ausfüllt, zur Auflistungs-Fassung wechselt und zurückkommt, verlöre die Eingaben
  der jeweils anderen Seite.
- **Die unbekannte Platzhaltermenge fällt für Pflicht und Sichtbarkeit in entgegengesetzte
  Richtungen.** Die leere Menge (Datei nicht lesbar) macht *nichts* zur Pflicht — „solange nichts
  bekannt ist: nicht sperren" —, lässt aber *alles* sichtbar: derselbe Rückfall verschlänge sonst
  das ganze Formular. Deshalb hat `VerwendeteFelder` neben `wirdVerwendet` (mit Rückfall) das
  rückfallfreie `enthaelt`, das `_istPflicht` benutzt.
- **`VorgangsdatenHinweis` zählt nur die sichtbaren Vorbelegungen** (`ausfuell_formular.dart`).
  Vorbelegt werden weiterhin alle Felder — die eingeklappten behalten ihren Wert für die andere
  Fassung —, aber „6 Felder vorbelegt" über einem Formular mit drei Feldern schickt den Anwalt auf
  die Suche nach den anderen drei.

## Auswahlhilfe am Feld (#17)

- **Die Auswahlhilfe hängt an der Datenquelle, nicht am Feldtyp.** Welche Werte an einem Feld zur
  Wahl stehen, rechnet `DatenquelleVorschlaege.fuerFelder` aus der `FeldDatenquelle` — genau der
  Kette, die auch `VorgangPrefillMatcher` nimmt (gesetzte Quelle, sonst `FeldDatenquelleErkennung`
  über den Namen). Deshalb bekommt auch ein gewöhnliches `InputType.text` die Liste, sobald zu
  seiner Quelle mehrere Werte bekannt sind, und ein `InputType.kennzeichen` ohne bekannte Werte
  bekommt keine. Wer das am Feldtyp festmachte, hätte für dieselbe Angabe je Vorlage eine andere
  Bedienung — und müsste die Liste zweimal pflegen.
- **Ohne Kandidaten kein Symbol.** `AuswahlTextField` zeigt das Listensymbol nur bei nicht-leerer
  Kandidatenliste. Ein Knopf, der einen leeren Dialog öffnet, verspricht Hilfe und liefert nichts —
  schlechter als kein Knopf.
- **Vorbelegen und Anbieten sind zwei Entscheidungen zum selben Feld.** Kennt der Vorgang das
  eigene Kennzeichen, belegt es vor (`PrefillQuelle.vorgang`); kennt nur das Register es und dort
  genau einmal, belegt dieses vor (`PrefillQuelle.mandant`). Bei **mehreren** Registereinträgen
  bleibt das Feld leer — welches Fahrzeug im Unfall stand, weiß das Register nicht, und eines
  davon wäre in jedem zweiten Fall das falsche im Anspruchsschreiben (§1.3). Angeboten werden dann
  alle. Das Kennzeichen des **Gegners** kommt im Mandantenfeld unter keinen Umständen an; dafür
  gab es früher die Notbremse „bleibt lieber leer", die jetzt der Fall „genau eines" ersetzt.
- **`InputType.kennzeichen` steht in keiner Bestandsvorlage.** Der Wert wird erst geschrieben, wenn
  ihn jemand am Feld auswählt; bis dahin bleibt dort `text`. Das Backend hält `fields` als opakes
  JSON, aber `InputType.fromValue` wirft bei Unbekanntem — eine Vorlage mit dem neuen Wert lässt
  sich also von einer **älteren** App-Fassung nicht mehr laden. Beim Erkennen aus dem Namen steht
  das Kennzeichen **vor** der Datumsprüfung (`_feldtypFuer`): sonst fischte deren Wortliste
  `{{KennzeichenAmUnfalltag}}` ab und das Feld verlangte ein Datum.
- **Der Validator ist nicht der aus `vorgang_starten`.** `kennzeichenFeldValidator`
  (`presentation/widgets/kennzeichen_feld_validator.dart`) beanstandet nur, was `istKennzeichen`
  gar nicht lesen kann, während `kennzeichenValidator` beim Erfassen den Bindestrich verlangt. Hier
  muss er toleranter sein: Die Werte kommen aus mehreren Beständen und laufen über den Dialog
  ohnehin durch `normalizeKennzeichen` — eine strengere Prüfung beanstandete einen Wert, den die
  App selbst angeboten hat.
