# word_automation — Anspruchsschreiben aus Vorlage erzeugen

**Zweck:** Der Anwalt füllt zu einem Vorgang eine Word-Vorlage aus, prüft das Ergebnis als PDF,
legt es in der Mandantenakte ab und schließt den Vorgang ab. Größtes Feature (~60 Dateien).
**Anforderung:** `REQUIREMENTS.md` §4.4, §4.5, §4.6, §4.7, §4.8, §4.9
**Einstieg:** `presentation/pages/word_automation_page.dart`
**Zustand:** in `presentation/blocs/`: `WizardCubit` (Schritt + Eingaben), `DocumentBloc` (geladene Vorlagendatei),
`EditedDocumentBloc` (Erzeugung), `TemplatePdfPreviewBloc` + `ResultPdfPreviewBloc` (`pdf_preview_bloc.dart`),
`RvgCalculationBloc`, `StandardpositionenCubit`, `AktivePlatzhalterCubit` (Pflicht + Sichtbarkeit je Variante, #35/#82),
`EntwurfSicherungSteuerung` (sichert den angefangenen Stand am Vorgang entprellt, #133 Teil B — kein eigener
Bloc, vom `WizardCubit` gehalten).
Fremd eingebunden: `AblageCubit` (mandanten), `KanzleiSettingsBloc`, `FormTemplateOverviewBloc`, `VorgangCubit`.
**Domain:** Entities `DamageListing`, `GeneratedDocument`, `RvgCalculation`, `VorlagenUebersicht`,
`ArbeitsordnerAufraeumung`, `AblageFormat`, `StandardSchadenspositionen`; Dienste `DatenquelleVorschlaege`
(bekannte Werte je Datenquelle zur Auswahl am Feld, #17 — gezeigt von `AusfuellFeld`), `EntwurfAbweichung`
(welche Felder eines angefangenen Stands von der Vorbelegung abweichen, #133 Teil B — nur sie werden
gesichert und still angezeigt), `AusgangsBelegung` (Vorbelegung plus Datumsvorschlag für leere
Datumsfelder — Ausgangswert für `FormTemplateBuilder` und Vergleichsbasis im Ausfüllformular);
UseCases `FillOutTemplate`,
`ConvertDocxToPdf`, `ErzeugePdfFassung`, `CalculateRvgFees`, `GetVorlagenUebersicht`, `ArbeitsordnerAufraeumen`.
**Backend:** `Features/WordAutomation/`, `Features/PdfConversion/` ·
`GET /api/WordAutomation/vorlagen`, `POST /api/WordAutomation/replaced-document`,
`POST /api/WordAutomation/rvg-calculation`, `POST /api/WordAutomation/arbeitsordner/aufraeumen`,
`POST /api/PdfConversion/convert-from-path`; über `VorgangCubit` zusätzlich `PUT /api/Vorgaenge`
und `POST /api/Vorgaenge/abschliessen`; Standardpositionen über `GET`/`PUT /api/Settings/schadenspositionen`
**Tests:** `test/features/word_automation/` (Formularextraktion, `WizardCubit`, `EditedDocumentBloc`, Export, Beträge, RVG)

**Fallstricke**

- Der lange Rest steht in `FALLSTRICKE.md` daneben: Ablageformat, Vorgangsstatus, Vorsteuer,
  Wiederaufnahme eines Vorgangs, Vorlagenverknüpfung, Auswahlhilfe, der angefangene Stand (#133) und
  die Platzhalter, die die App selbst füllt (RVG, `{{Gesamtforderung}}`).
- Der angefangene Stand überlagert die Vorbelegung ohne Nachfrage, Feld für Feld — kein Angebot,
  keine Karte; ein Textknopf über dem Formular setzt bei Abweichung auf die Vorbelegung zurück.
- Der `IndexedStack` der Page hält alle vier Views auf den festen `WizardStep`-Enum-Indizes;
  sichtbar sind nur die aus `WizardState.steps`. Einen Schritt einfügen: Enum, `steps` und
  `children` gemeinsam ändern.
- Bei „mit Auflistung" erzeugt Schritt 1 **kein** Dokument, sondern legt nur `formData` ab; das
  `EditDocumentEvent` geht erst am Ende des Schadensaufstellungs-Schritts raus.
- Erzeugt wird in `Generated/Arbeit/<Vorgangsreferenz>/` (ohne Vorgang: „Ohne Vorgang"), benannt
  nach der Kanzlei-Konvention (§4.9, `domain/services/schreiben_dateiname.dart`): eine Korrektur
  behält ihre Nummer und ersetzt damit die vorige Fassung. `schliesseAblageAb`
  (`utils/ablage_abschluss.dart`) löscht den Ordner und schwenkt den Bloc auf die Akte um.
- Versand (§4.7) und Abschluss (§4.8) sind getrennt: Die Mail geht über `MailVersendenButton` hinaus
  (Feature `email_versand`, Anhänge aus `MailAnhangAuswahl.zu` — PDF vorausgewählt), das Häkchen im
  Abschlussdialog ist danach vorbelegt. Abgeschlossen wird von Hand; hier fällt der Arbeitsordner.
- Die Datasource setzt eigene `receiveTimeout`s (30 s Worderzeugung, 60 s PDF); global stehen im
  `NetworkModule` 3 s — ohne diese Überschreibung brechen beide Aufrufe ab.
