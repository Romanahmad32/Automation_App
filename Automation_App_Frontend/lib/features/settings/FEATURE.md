# settings — Kanzleistammdaten und App-Einstellungen

**Zweck:** Der Anwalt hinterlegt hier die Anfragerdaten für die Zentralruf-Anfrage, den
Postfach-Zugang samt Mail-Signatur, den Akten-Stammordner, laufende Auftragsnummer samt Abteilung,
die Farbe der Schadensaufstellungs-Titelzeile und das Erscheinungsbild.
**Anforderung:** `REQUIREMENTS.md` §7.1
**Einstieg:** `presentation/pages/settings_page.dart`
**Zustand:** `KanzleiSettingsBloc`
(`presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart`); der Reiter „Darstellung"
schreibt stattdessen in den `ThemeBloc` (`lib/core/theme/presentation/bloc/theme_bloc.dart`).
**Domain:** `KanzleiSettings` (ein einziger Satz für die ganze App) · `GetKanzleiSettings`,
`SaveKanzleiSettings`, `ErhoeheAuftragsnummer`
**Backend:** `Features/Settings/` · `GET /api/Settings`, `PUT /api/Settings`,
`POST /api/Settings/auftragsnummer/erhoehe`
**Tests:** — (nur indirekt: `test/features/vorgang_starten/vorgang_starten_bloc_test.dart` fälscht
`GetKanzleiSettings`)

**Fallstricke**

- `ErhoeheAuftragsnummer` und `POST /api/Settings/auftragsnummer/erhoehe` haben **keinen Aufrufer**.
  Hochgezählt wird im Backend innerhalb der Abschluss-Transaktion (`VorgangAbschlussService`, über
  `POST /api/Vorgaenge/abschliessen`). Wer den UseCase nach dem Abschließen aufruft, zählt doppelt.
- `PUT /api/Settings` ersetzt **alle** Felder des Einstellungssatzes, und `AppSettingsView` füllt das
  Formular wegen `_initialized` nur einmal. Wurde die Auftragsnummer zwischenzeitlich durch einen
  Vorgangsabschluss erhöht, schreibt ein späteres „Speichern" den veralteten Stand zurück.
- `AppSettingsView` braucht `wantKeepAlive` (im Code begründet): ohne KeepAlive verwirft die TabBarView
  beim Tab-Wechsel den State, der Bloc steht schon auf `Loaded` und der Listener feuert nicht erneut — das
  Formular wäre leer.
- `KanzleiSettingsBloc` ist `@injectable`, also eine Factory. `word_automation_page.dart` erzeugt eine
  eigene Instanz und sendet `LoadKanzleiSettingsEvent` selbst; eine Änderung in den Einstellungen
  erreicht bereits offene Seiten nicht.
- Fremdabhängigkeiten: `mandanten` liest `aktenStammordner` (`mandanten_repository_impl.dart`,
  `ablage_cubit/ablage_cubit.dart`), `vorgang_starten` liest `laufendeAuftragsnummer`/`abteilung`.
  Beide werten einen Ladefehler als leeren Stammordner (`Left() => ''`) — ein Backend-Fehler sieht
  dort aus wie „kein Ordner gewählt".
- Die Reiter „E-Mail" und „Datensicherung" gehören den Features `mailbox` bzw. `backup`;
  `DefaultTabController(length: 5)` ist beim Ergänzen eines Reiters mitzupflegen.
- Die **Mail-Signatur** steht im Reiter „E-Mail" (`MailSignaturSektion`), liegt aber im selben Einstellungssatz und speichert
  über `SaveMailSignaturEvent` **für sich**; `…Loaded.gespeichert` sagt, welcher Reiter gespeichert hat. Deshalb setzt
  `AppSettingsView._save` per `copyWith` auf dem geladenen Stand auf — sonst löscht es die Felder der Nachbarreiter mit.
