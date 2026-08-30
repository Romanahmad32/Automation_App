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
