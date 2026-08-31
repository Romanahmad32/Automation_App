# form_template_setup — Fallstricke

Der lange Teil des Steckbriefs `FEATURE.md`. Hier steht, was beim Einrichten einer Vorlage
regelmäßig schiefgeht — die kurzen Merksätze bleiben drüben.

## Vom Namen zur Datenquelle

`FeldDatenquelleErkennung` (`domain/services/`) löst einen Platzhalternamen zu einer
`FeldDatenquelle` auf. Sie wird an **zwei** Stellen gebraucht, und das ist der Grund, warum es sie
gibt: hier beim Übernehmen eines Platzhalters (Vorauswahl im Dropdown, sichtbar und änderbar) und
zur Laufzeit im `VorgangPrefillMatcher` für Bestandsfelder, an denen nie eine Quelle gesetzt wurde.

Vorher lagen dieselben Stichwörter in drei Listen mit je eigener Prüfreihenfolge: eine für die
Mandantenfelder, der inzwischen abgeschaffte `VorgangsdatenFieldMatcher` für die Antwortfelder,
und das Dropdown. Was der Anwalt sah, war deshalb etwas anderes als das, was beim Ausfüllen
passierte.

- **Die Reihenfolge der Prüfungen ist die Regel** — spezifisch vor allgemein. Wer eine Zeile
  verschiebt, ändert das Verhalten; die Tests halten jede Regel einzeln fest.
- Ganz vorn stehen die Unfallangaben, erst danach die Beteiligten: `{{Unfallort des
  Geschädigten}}` meint den Ort des Unfalls. Andersherum fischte das „ort" der Mandantengruppe
  den Namen ab, und das Schreiben trüge still den Wohnort. Wörter wie „unfallort", „unfalltag"
  oder „polizei" benennen nie eine Stammdatenangabe — nur deshalb dürfen sie vorne stehen.
- Nennt ein Name zwei einzeln gespeicherte Angaben (`{{VersicherungPlzOrt}}`,
  `{{MandantVornameNachname}}`), bindet die Erkennung ihn **nicht**, und `FeldNameHinweis` sagt
  unter dem Feld, warum. Grund: Solche Namen lieferten früher still nur die erste der beiden
  Angaben — der Fehler steckte damit in jedem erzeugten Brief, statt einmal hier aufzufallen.
- Die Abgrenzung dahinter: **einzeln gespeichert → eigene Datenquelle; Zusammensetzung → zwei
  Platzhalter nebeneinander in der Word-Datei.** Ausnahme sind die Anschriften
  (`mandantAnschrift`, `versichererAnschrift`): Sie lassen fehlende Teile weg, was zwei
  Platzhalter nebeneinander nicht können — dort bliebe eine Leerstelle samt wanderndem Komma.
- Der Hinweis schweigt, sobald am Feld eine Datenquelle gewählt ist: Dann hat der Anwalt
  entschieden, und eine gesetzte Quelle gewinnt immer über die Erkennung.

## Platzhalter und Dateien

- Erlaubte Zeichen im Platzhalternamen prüft erst das Backend beim Erzeugen
  (`^[\p{L}\p{N} _-]+$`, sonst 400): ein Label mit Punkt oder Doppelpunkt lässt sich hier speichern
  und scheitert erst im Wizard.
- Die Datei im Slot „mit Auflistung“ muss `{{Schadensaufstellung}}` enthalten, sonst schlägt die
  Erzeugung fehl; die Karte warnt nur, sie blockiert das Speichern nicht. Der Chip zu diesem
  Platzhalter wird trotzdem angeboten — als Eingabefeld übernehmen wäre falsch, die Tabelle setzt
  ihn selbst ein.
- Der Word-Pfad läuft im Frontend absolut und wird auch aus `word_automation` überschrieben
  (`WizardCubit.linkWordFileToTemplate`). Gespeichert wird er seit #33 im **Backend** relativ zum
  eingestellten Vorlagenordner, sofern die Datei darin liegt (`FormTemplatesController`) — das
  Frontend rechnet nie um. Eine Datei außerhalb bietet `_pickFile` zum Hineinkopieren an
  (`VorlagenHineinholen`); abgelehnt bleibt sie absolut verknüpft und fehlt in der Sicherung.
  `fields` liegt im Backend als opakes JSON — das Schema
  lebt nur in Dart, ein unbekannter `inputType` wirft beim Laden (`InputType.fromValue`). Tot:
  `FormTemplateField` (gemeint ist `FieldData`) und `getFormTemplateByName`.

## Zustand

- `FormTemplateOverviewBloc` ist bewusst `@lazySingleton` (Verwaltung und Wizard-Dropdown teilen
  ihn): per `BlocProvider.value` einbinden, sonst schließt ihn die Seite beim Verlassen; nach der
  Rückkehr aus der Detailseite braucht es ein `LoadFormTemplatesEvent`.
