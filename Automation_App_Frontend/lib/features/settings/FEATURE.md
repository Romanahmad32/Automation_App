# settings — Kanzleistammdaten und App-Einstellungen

**Zweck:** Anfragerdaten für die Zentralruf-Anfrage, Postfach-Zugang samt Mail-Signatur, der **eine** Ordner
für alles, was die App selbst ablegt (Vorlagen, Register §6.2, Sicherungen §7.2), daneben der
Akten-Stammordner (§6.1), Auftragsnummer samt Abteilung, Erscheinungsbild samt Schriftgröße.
**Anforderung:** `REQUIREMENTS.md` §7.1
**Einstieg:** `presentation/pages/settings_page.dart`
**Zustand:** `KanzleiSettingsBloc`
(`presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart`); der Reiter „Darstellung"
schreibt stattdessen in den `ThemeBloc` (`lib/core/theme/presentation/bloc/theme_bloc.dart`): Design, Hell/Dunkel, Schriftstufe.
**Domain:** `KanzleiSettings` (ein einziger Satz für die ganze App) · `OrdnerZustand` samt
`OrdnerZustandArten` (nur lesend: je Ordner Speicherform, wirksamer Ordner, Grund) ·
`SynchronisierterOrdner`/`SynchronisierterWurzelOrdner` (OneDrive-Erkennung; schlägt vor, setzt nie) ·
`GetKanzleiSettings`, `SaveKanzleiSettings`, `GetOrdnerZustand`, `ErhoeheAuftragsnummer`
**Backend:** `Features/Settings/` · `GET /api/Settings`, `PUT /api/Settings`,
`GET /api/Settings/ordner`, `POST /api/Settings/auftragsnummer/erhoehe`
**Tests:** `test/features/settings/` (Kanzleidaten- und Signatur-Anzeige, Speichern, Ordner-Sektion,
Zustandszeile, OneDrive-Erkennung, Schriftgröße) · indirekt
`test/features/vorgang_starten/vorgang_starten_bloc_test.dart`, das `GetKanzleiSettings` fälscht

**Fallstricke** — das Ausführliche steht in `FALLSTRICKE.md` daneben.

- `ErhoeheAuftragsnummer` und `POST /api/Settings/auftragsnummer/erhoehe` haben **keinen Aufrufer**. Hochgezählt wird im Backend
  in der Abschluss-Transaktion (`VorgangAbschlussService`); wer den UseCase danach aufruft, zählt doppelt.
- `PUT /api/Settings` ersetzt **alle** Felder, und `AppSettingsView` füllt das Formular wegen `_initialized` nur einmal: Wurde die
  Auftragsnummer zwischenzeitlich durch einen Abschluss erhöht, schreibt „Speichern" den alten Stand zurück.
- Jeder Reiter zeichnet seine Kopfzeile selbst (`EinstellungenReiter` → `EinstellungenAktionszeile`): links die Abschnittswahl,
  rechts fest `aktionsbreite`, auch ohne Knopf. Ohne `DefaultTabController` fehlt die Wahl, der Reiter bleibt bedienbar.
- `KanzleiSettingsBloc` ist `@injectable`, also eine Factory. `word_automation_page.dart` erzeugt eine eigene Instanz und lädt
  selbst; eine Änderung in den Einstellungen erreicht bereits offene Seiten nicht.
- Fremdabhängigkeiten: `mandanten` liest `aktenStammordner`, `vorgang_starten` liest `laufendeAuftragsnummer`/`abteilung`. Beide
  werten einen Ladefehler als leeren Wert (`Left() => ''`) — ein Backend-Fehler sieht dort aus wie „kein Ordner gewählt".
- Reiter „Schadensaufstellung"/„E-Mail"/„Datensicherung" gehören `word_automation`/`mailbox`/`backup`. Reihenfolge der Ansichten
  in `settings_page.dart` und `EinstellungenAktionszeile.abschnitte` mitpflegen — der Index ist das einzige Band. Die
  Titelzeilen-Farbe liegt im Schadensaufstellungs-Reiter und speichert dort für sich, sofort (`SaveTabellenkopfFarbeEvent`).
- Alle fünf Ordner stehen in **einer** Karte (`OrdnerSektion`); die drei Einzelfelder im Aufklapper
  `AbweichendeOrdnerAufklapper`, Name/Zeitpunkt/Filter des Registers dagegen daneben in `RegisterSpiegelFelder` — sie sind
  keine Ordnerwahl und dürfen nicht mit eingeklappt werden.
- Die **Mail-Signatur** (Reiter „E-Mail") und die **relativ abgelegten Ordnerpfade** haben jeweils eine Geschichte, die hier
  nicht in vierzig Zeilen passt — beides steht in `FALLSTRICKE.md`.
