# word_automation — Anspruchsschreiben aus Vorlage erzeugen

**Zweck:** Der Anwalt füllt zu einem Vorgang eine Word-Vorlage aus, prüft das Ergebnis als PDF,
legt es in der Mandantenakte ab und schließt den Vorgang ab. Größtes Feature (~58 Dateien).
**Anforderung:** `REQUIREMENTS.md` §4.4, §4.5, §4.6, §4.8
**Einstieg:** `presentation/pages/word_automation_page.dart`
**Zustand:** in `presentation/blocs/`: `WizardCubit` (Schritt + gesammelte Eingaben), `DocumentBloc`
(geladene Vorlagendatei), `EditedDocumentBloc` (Erzeugung), `TemplatePdfPreviewBloc` +
`ResultPdfPreviewBloc` (`pdf_preview_bloc.dart`), `RvgCalculationBloc`. Fremd eingebunden:
`AblageCubit` (mandanten), `KanzleiSettingsBloc`, `FormTemplateOverviewBloc`, `VorgangCubit`.
**Domain:** Entities `DamageListing`, `GeneratedDocument`, `RvgCalculation`, `VorlagenUebersicht`;
UseCases `FillOutTemplate`, `ConvertDocxToPdf`, `CalculateRvgFees`, `GetVorlagenUebersicht`.
**Backend:** `Features/WordAutomation/`, `Features/PdfConversion/` · `GET /api/WordAutomation/vorlagen`,
`POST /api/WordAutomation/replaced-document`, `POST /api/WordAutomation/rvg-calculation`,
`POST /api/PdfConversion/convert-from-path`; über `VorgangCubit` zusätzlich `PUT /api/Vorgaenge`
und `POST /api/Vorgaenge/abschliessen`
**Tests:** `test/features/word_automation/formular_extraktion_test.dart`,
`test/features/word_automation/wizard_cubit_select_vorgang_test.dart`

**Fallstricke**

- Der `IndexedStack` der Page hält immer alle vier Views auf den festen `WizardStep`-Enum-Indizes;
  sichtbar sind nur die aus `WizardState.steps`, `goToStep` blockt den Rest. Einen Schritt einfügen
  heißt: Enum-Position, `steps` und die `children`-Liste gemeinsam ändern.
- Bei „mit Auflistung" erzeugt Schritt 1 **kein** Dokument, sondern legt nur `formData` ab; das
  `EditDocumentEvent` geht erst am Ende des Schadensaufstellungs-Schritts raus.
- Die Vorsteuer-Checkbox steht in zwei gleichzeitig gemounteten Schritten auf demselben Cubit-Feld;
  es gilt `applyVat == !vorsteuerabzugsberechtigt`, ein Listener rechnet die RVG-Kosten bei jeder
  Änderung neu, und die Änderung im Schadensschritt ist bewusst dialogbestätigt.
- Der Vorgangsstatus wird an drei Stellen weitergeschaltet, je nur vorwärts über `status.index`:
  „erstellt" im Listener der Page, „abgelegt" in `akten_ablage_section.dart`, „versendet" über
  `VorgangCubit.abschliessen`. Vorher immer `findeZuReferenz` — der Vorgang im Wizard-State ist alt.
- „Vorgang abschließen" verlangt im Dialog das Häkchen „E-Mail wurde versendet" (der Versand ist
  nicht gebaut, §4.7); erst danach zählt das Backend die laufende Auftragsnummer hoch. Bewusster
  Handgriff, nicht wegautomatisieren.
- Die Datasource setzt eigene `receiveTimeout`s (30 s Worderzeugung, 60 s PDF); global stehen im
  `NetworkModule` 3 s — ohne diese Überschreibung brechen beide Aufrufe ab.
- `linkWordFileToTemplate` merkt sich die gewählte .docx am aktiven Vorlagen-Slot; die Vorlagenliste
  darf nur bei echter Neuverknüpfung neu geladen werden, sonst setzt das Resync im
  `TemplateSelector` die gerade getroffene Auswahl zurück.
