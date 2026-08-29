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

## Vorlagen

- `linkWordFileToTemplate` merkt sich die gewählte .docx am aktiven Vorlagen-Slot; die
  Vorlagenliste nur bei echter Neuverknüpfung neu laden, sonst setzt das Resync im
  `TemplateSelector` die Auswahl zurück.
