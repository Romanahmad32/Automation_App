# word_automation — Anspruchsschreiben aus Vorlage erzeugen

**Zweck:** Der Anwalt füllt zu einem Vorgang eine Word-Vorlage aus, prüft das Ergebnis als PDF,
legt es in der Mandantenakte ab und schließt den Vorgang ab. Größtes Feature (~60 Dateien).
**Anforderung:** `REQUIREMENTS.md` §4.4, §4.5, §4.6, §4.8
**Einstieg:** `presentation/pages/word_automation_page.dart`
**Zustand:** in `presentation/blocs/`: `WizardCubit` (Schritt + gesammelte Eingaben), `DocumentBloc`
(geladene Vorlagendatei), `EditedDocumentBloc` (Erzeugung), `TemplatePdfPreviewBloc` +
`ResultPdfPreviewBloc` (`pdf_preview_bloc.dart`), `RvgCalculationBloc`. Fremd eingebunden:
`AblageCubit` (mandanten), `KanzleiSettingsBloc`, `FormTemplateOverviewBloc`, `VorgangCubit`.
**Domain:** Entities `DamageListing`, `GeneratedDocument`, `RvgCalculation`, `VorlagenUebersicht`, `ArbeitsordnerAufraeumung`;
UseCases `FillOutTemplate`, `ConvertDocxToPdf`, `CalculateRvgFees`, `GetVorlagenUebersicht`, `ArbeitsordnerAufraeumen`.
**Backend:** `Features/WordAutomation/`, `Features/PdfConversion/` · `GET /api/WordAutomation/vorlagen`, `POST /api/WordAutomation/replaced-document`,
`POST /api/WordAutomation/rvg-calculation`, `POST /api/WordAutomation/arbeitsordner/aufraeumen`, `POST /api/PdfConversion/convert-from-path`;
über `VorgangCubit` zusätzlich `PUT /api/Vorgaenge` und `POST /api/Vorgaenge/abschliessen`
**Tests:** `test/features/word_automation/` (Formularextraktion, `WizardCubit`, `EditedDocumentBloc`)

**Fallstricke**

- Der `IndexedStack` der Page hält alle vier Views auf den festen `WizardStep`-Enum-Indizes; sichtbar sind
  nur die aus `WizardState.steps`. Einen Schritt einfügen: Enum, `steps` und `children` gemeinsam ändern.
- Bei „mit Auflistung" erzeugt Schritt 1 **kein** Dokument, sondern legt nur `formData` ab; das
  `EditDocumentEvent` geht erst am Ende des Schadensaufstellungs-Schritts raus.
- Erzeugt wird in `Generated/Arbeit/<Vorgangsreferenz>/` unter stets demselben Namen — eine Korrektur
  ersetzt die vorige Fassung, statt eine „(2)" danebenzulegen; ohne Vorgang gilt „Ohne Vorgang".
  `schliesseAblageAb` (`utils/ablage_abschluss.dart`) löscht den Ordner nach der Ablage und schwenkt den
  `EditedDocumentBloc` per `DokumentAbgelegtEvent` auf die Kopie in der Akte um — beides kann sein Pfad sein.
- Die Vorsteuer-Checkbox steht in zwei gleichzeitig gemounteten Schritten auf demselben Cubit-Feld
  (`applyVat == !vorsteuerabzugsberechtigt`); ein Listener rechnet die RVG-Kosten neu, und die Änderung im
  Schadensschritt ist bewusst dialogbestätigt.
- Der Vorgangsstatus wird nur vorwärts geschaltet (`status.index`): „erstellt" im Listener der Page, „abgelegt"
  in `schliesseAblageAb`, „versendet" über `VorgangCubit.abschliessen`. Vorher immer `findeZuReferenz` — der
  Vorgang im Wizard-State ist alt.
- „Vorgang abschließen" verlangt im Dialog das Häkchen „E-Mail wurde versendet" (der Versand ist nicht
  gebaut, §4.7); erst danach zählt das Backend die Auftragsnummer hoch. Nicht wegautomatisieren.
- Die Datasource setzt eigene `receiveTimeout`s (30 s Worderzeugung, 60 s PDF); global stehen im
  `NetworkModule` 3 s — ohne diese Überschreibung brechen beide Aufrufe ab.
- `linkWordFileToTemplate` merkt sich die gewählte .docx am aktiven Vorlagen-Slot; die Vorlagenliste nur
  bei echter Neuverknüpfung neu laden, sonst setzt das Resync im `TemplateSelector` die Auswahl zurück.
