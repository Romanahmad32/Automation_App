# form_template_setup — Felder einer Word-Vorlage beschreiben

**Zweck:** Der Anwalt verknüpft je Vorlage bis zu zwei Word-Dateien (ohne und mit
Schadensaufstellung) und beschreibt deren Eingabefelder; daraus baut „Word Automation“ das Formular.
**Anforderung:** `REQUIREMENTS.md` §5.3
**Einstieg:** `presentation/pages/form_template_details_page.dart` — Ablauf **Datei zuerst**, leer via `VorlagenLeerzustand`.
**Zustand:** `presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart`,
`presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart`,
`presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart`
**Domain:** `FormTemplate`, `FieldData`, `DatumsVorbelegung`, `InputType`, `FeldDatenquelle` (+ `platzhalter`, `gruppe`,
`frueher`), `PlatzhalterGruppe`, `PlatzhalterEintrag`, `CreateFormTemplateRequest`; Dienste `FeldDatenquelleErkennung`
(+ `DatenquelleVorschlag`), `PlatzhalterKatalog`, `AppEigenePlatzhalter`, `PlatzhalterUebernahme`, `FeldVorkommen`,
`PlatzhalterZuordnung`, `VerwendeteFelder` (welche Felder die aktive Word-Datei einsetzt, #82), `VorlagenStand`,
`FelderFilter`, `VorlagennameVorschlag`, `FeldAbgleich`, `VorlagenEntwurf`; `GetFormTemplates`, `CreateFormTemplate`,
`UpdateFormTemplate`, `DeleteFormTemplate`, `GetTemplatePlaceholders`
**Backend:** `Features/FormTemplates/` · `GET /api/FormTemplates`, `POST /api/FormTemplates`,
`PUT /api/FormTemplates/{id}`, `DELETE /api/FormTemplates/{id}`; Platzhalter-Erkennung aus
`Features/WordAutomation/` · `POST /api/WordAutomation/template-placeholders`
**Tests:** `test/features/form_template_setup/` — `feld_vorkommen_badge_test.dart`, `datums_vorbelegung_speicherweg_test.dart`,
`feld_datenquelle_erkennung_test.dart`, `feld_vorkommen_test.dart`, `verwendete_felder_test.dart`, `datums_vorbelegung_test.dart`

**Fallstricke**

- **`FeldDatenquelle.platzhalter` ist der Rückweg** und muss ihn einhalten: Jeder angebotene Name muss über
  `FeldDatenquelleErkennung` wieder auf **seinen** Eintrag auflösen — das erzwingt `feld_datenquelle_test.dart` über alle
  Werte. Wer eine Datenquelle ergänzt, gibt ihr einen Namen oder begründet im Test, warum sie keinen hat; zwei Quellen sind
  heute namentlich ausgenommen, weil sie über einen Namen nicht erreichbar sind (§4.7, ergänzt am 02.09.2026).
- Der Feldname **ist** der Platzhaltername: beim Ausfüllen wird `FieldData.label` zum Schlüssel in `replacePatterns` und
  ersetzt `{{label}}` (ohne Groß-/Kleinschreibung). Ein Platzhalter ohne Feld bleibt als `{{…}}` im Dokument stehen und kommt
  als Warnung zurück — gewollt; ein Feld ohne Platzhalter bleibt wirkungslos. Beides wird beim **Einrichten** gemeldet und
  über den `ZuordnungsDialog` repariert (#36), statt erst nach dem Erzeugen aufzufallen.
- **`VorlagenVerlassenWache`** (#104, §1.3) fragt beim Verlassen der Detailseite nach, wenn der aktuelle Stand vom
  `VorlagenEntwurf`-Schnappschuss abweicht. Solange die Seite offen ist, hält `FieldData.label` **nicht** den Feldnamen, sondern
  den Control-Schlüssel (`field_0`, `field_1`, …) — `VorlagenEntwurf.aufnehmen` löst ihn wie `FormTemplateActionButtons`
  beim Speichern zum echten Namen auf.
- Beim Übernehmen eines Platzhalters schlägt `FeldDatenquelleErkennung` Feldtyp und Datenquelle vor — sichtbar im Dropdown,
  änderbar, nie stillschweigend gesetzt (§1.3); dieselbe Erkennung greift zur Laufzeit an Feldern ohne Quelle.
- Der lange Rest steht in `FALLSTRICKE.md` daneben: Erkennungsregeln, mehrdeutige Namen, erlaubte Zeichen im Platzhalter, Slot
  „mit Auflistung“, Word-Pfad, `FormTemplateOverviewBloc`, Vorbelegung, Verlassen-Wache, Spaltenbeschreibung, Aufklapper,
  `VorlagenBearbeitung`, Layout, Datei zuerst, Abgleich.
