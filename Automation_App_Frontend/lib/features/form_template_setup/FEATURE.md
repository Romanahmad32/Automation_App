# form_template_setup — Felder einer Word-Vorlage beschreiben

**Zweck:** Der Anwalt verknüpft je Vorlage bis zu zwei Word-Dateien (ohne und mit
Schadensaufstellung) und beschreibt deren Eingabefelder; daraus baut „Word Automation“ das Formular.
**Anforderung:** `REQUIREMENTS.md` §5.3
**Einstieg:** `presentation/pages/form_template_details_page.dart`
**Zustand:** `presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart`,
`presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart`,
`presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart`
**Domain:** `FormTemplate`, `FieldData`, `InputType`, `FeldDatenquelle` (+ `platzhalter`, `gruppe`, `frueher`),
`PlatzhalterGruppe`, `PlatzhalterEintrag`, `CreateFormTemplateRequest`; Dienste `FeldDatenquelleErkennung`
(+ `DatenquelleVorschlag`), `PlatzhalterKatalog`, `AppEigenePlatzhalter`, `PlatzhalterUebernahme`,
`FeldVorkommen`, `PlatzhalterZuordnung`, `VerwendeteFelder` (welche Felder die aktive Word-Datei einsetzt, #82);
`GetFormTemplates`, `CreateFormTemplate`, `UpdateFormTemplate`, `DeleteFormTemplate`, `GetTemplatePlaceholders`
**Backend:** `Features/FormTemplates/` · `GET /api/FormTemplates`, `POST /api/FormTemplates`,
`PUT /api/FormTemplates/{id}`, `DELETE /api/FormTemplates/{id}`; Platzhalter-Erkennung aus
`Features/WordAutomation/` · `POST /api/WordAutomation/template-placeholders`
**Tests:** `test/features/form_template_setup/` — `feld_datenquelle_erkennung_test.dart`,
`feld_vorkommen_test.dart`, `feld_vorkommen_badge_test.dart`, `verwendete_felder_test.dart`

**Fallstricke**

- **`FeldDatenquelle.platzhalter` ist der Rückweg** und muss ihn einhalten: Jeder angebotene Name
  muss über `FeldDatenquelleErkennung` wieder auf **seinen** Eintrag auflösen — das erzwingt
  `feld_datenquelle_test.dart` über alle Werte. Wer eine Datenquelle ergänzt, gibt ihr einen Namen
  oder begründet im Test, warum sie keinen hat; zwei Quellen sind heute namentlich ausgenommen,
  weil sie über einen Namen nicht erreichbar sind (§4.7, ergänzt am 02.09.2026).
- Der Feldname **ist** der Platzhaltername: beim Ausfüllen wird `FieldData.label` zum Schlüssel in
  `replacePatterns` und ersetzt `{{label}}` (ohne Groß-/Kleinschreibung). Ein Platzhalter ohne Feld
  bleibt als `{{…}}` im Dokument stehen und kommt als Warnung zurück — gewollt; ein Feld ohne
  Platzhalter bleibt wirkungslos. Beides wird beim **Einrichten** gemeldet und über den
  `ZuordnungsDialog` repariert (#36), statt erst nach dem Erzeugen aufzufallen.
- Solange die Detailseite offen ist, hält `FieldData.label` **nicht** den Feldnamen, sondern den
  Schlüssel des reactive_forms-Controls (`field_0`, `field_1`, …); der Name steht im Wert des
  Controls und wird erst beim Speichern in `FormTemplateActionButtons` zurückgetauscht.
- Beim Übernehmen eines Platzhalters schlägt `FeldDatenquelleErkennung` Feldtyp und Datenquelle
  vor — sichtbar im Dropdown und änderbar, nie stillschweigend gesetzt (§1.3). Dieselbe Erkennung
  löst zur Laufzeit die Felder auf, an denen nie eine Quelle gesetzt wurde.
- Der lange Rest steht in `FALLSTRICKE.md` daneben: Erkennungsregeln und mehrdeutige Namen,
  erlaubte Zeichen im Platzhalter, Slot „mit Auflistung“, Word-Pfad und `FormTemplateOverviewBloc`.
