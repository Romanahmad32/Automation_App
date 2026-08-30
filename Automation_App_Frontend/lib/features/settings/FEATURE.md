# settings — Kanzleistammdaten und App-Einstellungen

**Zweck:** Der Anwalt hinterlegt hier die Anfragerdaten für die Zentralruf-Anfrage, den Postfach-Zugang samt
Mail-Signatur, Akten-Stammordner, Auftragsnummer samt Abteilung, Titelzeilen-Farbe und Erscheinungsbild.
**Anforderung:** `REQUIREMENTS.md` §7.1
**Einstieg:** `presentation/pages/settings_page.dart`
**Zustand:** `KanzleiSettingsBloc`
(`presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart`); der Reiter „Darstellung"
schreibt stattdessen in den `ThemeBloc` (`lib/core/theme/presentation/bloc/theme_bloc.dart`).
**Domain:** `KanzleiSettings` (ein einziger Satz für die ganze App) · `GetKanzleiSettings`,
`SaveKanzleiSettings`, `ErhoeheAuftragsnummer`
**Backend:** `Features/Settings/` · `GET /api/Settings`, `PUT /api/Settings`,
`POST /api/Settings/auftragsnummer/erhoehe`
**Tests:** `test/features/settings/` (Kanzleidaten- und Signatur-Anzeige, Speichern) · indirekt
`test/features/vorgang_starten/vorgang_starten_bloc_test.dart`, das `GetKanzleiSettings` fälscht

**Fallstricke**

- `ErhoeheAuftragsnummer` und `POST /api/Settings/auftragsnummer/erhoehe` haben **keinen Aufrufer**. Hochgezählt wird
  im Backend in der Abschluss-Transaktion (`VorgangAbschlussService`); wer den UseCase danach aufruft, zählt doppelt.
- `PUT /api/Settings` ersetzt **alle** Felder, und `AppSettingsView` füllt das Formular wegen `_initialized` nur einmal:
  Wurde die Auftragsnummer zwischenzeitlich durch einen Abschluss erhöht, schreibt „Speichern" den alten Stand zurück.
- `AppSettingsView` braucht `wantKeepAlive` (im Code begründet): ohne KeepAlive verwirft die TabBarView beim
  Tab-Wechsel den State, der Bloc steht auf `Loaded`, der Listener feuert nicht erneut — das Formular wäre leer.
- `KanzleiSettingsBloc` ist `@injectable`, also eine Factory. `word_automation_page.dart` erzeugt eine eigene
  Instanz und lädt selbst; eine Änderung in den Einstellungen erreicht bereits offene Seiten nicht.
- Fremdabhängigkeiten: `mandanten` liest `aktenStammordner`, `vorgang_starten` liest
  `laufendeAuftragsnummer`/`abteilung`. Beide werten einen Ladefehler als leeren Wert (`Left() => ''`) — ein
  Backend-Fehler sieht dort aus wie „kein Ordner gewählt".
- Reiter „Schadensaufstellung"/„E-Mail"/„Datensicherung" gehören `word_automation`/`mailbox`/`backup`;
  `DefaultTabController(length: 6)` mitpflegen. Die Titelzeilen-Farbe liegt im Schadensaufstellungs-Reiter
  und speichert dort für sich, sofort beim Auswählen (`SaveTabellenkopfFarbeEvent`).
- Die **Mail-Signatur** steht im Reiter „E-Mail" (`MailSignaturSektion`) und schreibt über `SaveMailSignaturEvent`
  **für sich**; `…Loaded.gespeichert` sagt, welcher Reiter gespeichert hat. Deshalb setzt `AppSettingsView._save` per
  `copyWith` auf dem geladenen Stand auf — sonst löscht es die Felder der Nachbarreiter mit. Einen **eigenen Knopf**
  hat sie trotzdem nicht: Den einen der Seite ruft `MailboxAccessView._save`, er schreibt beides
  (`speichereWennGeaendert`) — zwei Knöpfe „Speichern" untereinander sahen aus wie zwei Formulare.
- `mailSignaturHtml` wird **nur durchgereicht**: Übernommen und verworfen wird die formatierte Signatur im Dienst
  (`POST/DELETE api/EmailVersand/signaturen/…`), weil dabei Bilder abzulegen sind. Nach einer Übernahme lädt
  `MailSignaturSektion` die Einstellungen neu — sonst schriebe das nächste Speichern die alte Fassung zurück.
