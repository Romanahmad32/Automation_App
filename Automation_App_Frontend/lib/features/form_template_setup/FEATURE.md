# form_template_setup — Felder einer Word-Vorlage beschreiben

**Zweck:** Der Anwalt verknüpft je Vorlage bis zu zwei Word-Dateien (ohne und mit
Schadensaufstellung) und beschreibt deren Eingabefelder; daraus baut „Word Automation“ das Formular.
**Anforderung:** `REQUIREMENTS.md` §5.3
**Einstieg:** `presentation/pages/form_template_details_page.dart`
**Zustand:** `presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart`,
`presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart`,
`presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart`
**Domain:** `FormTemplate`, `FieldData`, `InputType`, `FeldDatenquelle`,
`CreateFormTemplateRequest`; `GetFormTemplates`, `CreateFormTemplate`, `UpdateFormTemplate`,
`DeleteFormTemplate`, `GetTemplatePlaceholders`
**Backend:** `Features/FormTemplates/` · `GET /api/FormTemplates`, `POST /api/FormTemplates`,
`PUT /api/FormTemplates/{id}`, `DELETE /api/FormTemplates/{id}`; Platzhalter-Erkennung aus
`Features/WordAutomation/` · `POST /api/WordAutomation/template-placeholders`
**Tests:** —

**Fallstricke**

- Der Feldname **ist** der Platzhaltername: beim Ausfüllen wird `FieldData.label` zum Schlüssel in
  `replacePatterns` und ersetzt `{{label}}` (ohne Groß-/Kleinschreibung). Ein Platzhalter ohne Feld
  bleibt als `{{…}}` im Dokument stehen und kommt als Warnung zurück — gewollt; ein Feld ohne
  Platzhalter bleibt wirkungslos.
- Solange die Detailseite offen ist, hält `FieldData.label` **nicht** den Feldnamen, sondern den
  Schlüssel des reactive_forms-Controls (`field_0`, `field_1`, …); der Name steht im Wert des
  Controls und wird erst beim Speichern in `FormTemplateActionButtons` zurückgetauscht.
- Erlaubte Zeichen im Platzhalternamen prüft erst das Backend beim Erzeugen
  (`^[\p{L}\p{N} _-]+$`, sonst 400): ein Label mit Punkt oder Doppelpunkt lässt sich hier speichern
  und scheitert erst im Wizard.
- Die Datei im Slot „mit Auflistung“ muss `{{Schadensaufstellung}}` enthalten, sonst schlägt die
  Erzeugung fehl; die Karte warnt nur, sie blockiert das Speichern nicht. Der Chip zu diesem
  Platzhalter wird trotzdem angeboten — als Eingabefeld übernehmen wäre falsch, die Tabelle setzt
  ihn selbst ein.
- `FormTemplateOverviewBloc` ist bewusst `@lazySingleton` (Verwaltung und Wizard-Dropdown teilen
  ihn): per `BlocProvider.value` einbinden, sonst schließt ihn die Seite beim Verlassen; nach der
  Rückkehr aus der Detailseite braucht es ein `LoadFormTemplatesEvent`.
- Der Word-Pfad wird absolut gespeichert und auch aus `word_automation` überschrieben
  (`WizardCubit.linkWordFileToTemplate`). `fields` liegt im Backend als opakes JSON — das Schema
  lebt nur in Dart, ein unbekannter `inputType` wirft beim Laden (`InputType.fromValue`). Tot:
  `FormTemplateField` (gemeint ist `FieldData`) und `getFormTemplateByName`.
