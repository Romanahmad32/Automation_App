# register_import — Registerhistorie in Jahrgängen übernehmen

**Zweck:** Nimmt das Word-Register der Kanzlei (rund 90 Seiten) Jahrgang für Jahrgang in die App:
Datei einlesen, Lücken in der Nummernfolge, Doppelte und Widersprüche zeigen, einzelne Zeilen
berichtigen, dann übernehmen. Bearbeiten und Anzeigen der übernommenen Zeilen liegen in `vorgaenge`.
**Anforderung:** `REQUIREMENTS.md` §6.2
**Einstieg:** `presentation/pages/register_import_page.dart`
**Zustand:** `RegisterImportCubit`/`RegisterImportState`
(`presentation/blocs/register_import_cubit/register_import_cubit.dart`) — Vorschau, Filter
„nur zu prüfen", Zeile ändern oder weglassen, Übernehmen je Jahrgang und für alle
**Domain:** `RegisterImportDatei`, `RegisterImportJahrgang`, `RegisterImportZeile`,
`RegisterImportBericht`, `JahrgangBefund`, `RegisterZeilenBefund`; `LiesRegisterImportDatei`,
`ImportiereRegister`; Port `RegisterImportRepository`. Sicherheitsstufe und Art kommen als
`ImportSicherheit`/`ImportArt` aus `mandanten` — ein zweites Wortpaar liefe auseinander.
**Backend:** `Features/RegisterHistorie/` · `POST /api/RegisterImport?uebernehmen=` — ohne den
Parameter nur Vorschau, mit ihm die Übernahme; derselbe Aufruf, derselbe Bericht.
**Tests:** `test/features/register_import/`, Einstieg
`test/features/register_import/register_import_cubit_test.dart`

**Fallstricke**

- **Übernommen wird je Jahrgang.** `uebernehmen(jahrgang: 2022)` schickt eine Datei mit nur diesem
  Jahrgang an denselben Endpunkt; die Karten der übrigen bleiben stehen, statt hinter dem Ergebnis
  eines einzigen zu verschwinden. „Alle übernehmen" oben schickt die ganze Datei.
- **`RegisterZeilenBefund.zeile` zählt 1-basiert innerhalb seines Jahrgangs**, nicht über die ganze
  Datei. `zeileErsetzen`/`zeileVerwerfen` rechnen damit; wer das umdreht, ändert bei mehreren
  Jahrgängen still die falsche Zeile.
- **Nichts wird berichtigt, was nicht der Anwalt berichtigt.** Widersprüche aus dem Bestand
  (Spalte 1 gegen Aktenzeichen, Abteilung gegen Rechtsgebiet, Tippfehler) werden übernommen wie sie
  sind und tragen einen Befund. Abgelehnt wird allein eine echte Doppelnummer.
- **Die Datei wird nicht selbst gelesen**: `ImportDateiDatasource.liesJson` aus `mandanten` holt sie
  von der Platte, gedeutet wird sie hier. Zwei Fassungen desselben Griffs liefen beim ersten
  Sonderfall auseinander (Codepage, BOM, leere Datei).
- **Die Route liegt über den Reitern** (`/register-import`), nicht unter der Shell: Tab 6 ist kein
  Stapel, und eine zehnte Kindroute wäre ein Reiter mehr. Geöffnet wird sie mit
  `context.router.push(RegisterImportRoute(vorgeschlagenerJahrgang: state.stand.vorschlag()))`.
- Jede Änderung an einer Zeile löst eine **neue Prüfung der ganzen Datei** aus. Das ist kein
  Aufwand, den man sparen sollte: Eine berichtigte Nummer kann eine Lücke schließen oder eine
  Doppelnummer auflösen. Lokal nachgerechnet gäbe es eine zweite Auslegung derselben Regeln.
