# vorgang_starten — Mandat erfassen, Zentralruf anfragen

**Zweck:** Der Anwalt erfasst Auftrags-, Mandanten- und Unfalldaten, legt daraus den Vorgang an und
lässt optional das Zentralruf-Onlineformular im sichtbaren Browser vorbefüllen.
**Anforderung:** `REQUIREMENTS.md` §4.1, §4.2 (Vorgang als Klammer: §3)
**Einstieg:** `presentation/views/vorgang_starten_form_view.dart`
**Zustand:** `VorgangStartenBloc` (`presentation/blocs/vorgang_starten_bloc.dart`, Events/States als
`part`-Dateien daneben) führt nur die Ausführung aus; die Feldwerte liegen in der
reactive_forms-`FormGroup` der View, die Dialog-Entscheidungen trifft ebenfalls die View.
Fremd eingebunden: `VorgangCubit` (vorgaenge).
**Domain:** kein eigener `domain/`-Ordner. Eingabecontainer ist `VorgangStartenDaten`
(`presentation/blocs/vorgang_starten_daten.dart`); verwendet werden `Vorgang`/`RechtsgebietWert`
(vorgaenge), `Mandant`/`CreateMandantRequest` (mandanten), `ZentralrufRequest`
(zentralruf_request), `KanzleiSettings` (settings) samt deren UseCases.
**Backend:** `Features/ZentralrufAutomation/` · `POST /api/Zentralruf/prefill`; mittelbar
`GET /api/Settings`, `POST /api/Mandanten`, `PUT /api/Mandanten/{id}`, `PUT /api/Vorgaenge`
**Tests:** `test/features/vorgang_starten/vorgang_starten_bloc_test.dart`,
`test/features/vorgang_starten/mandant_aenderung_test.dart`,
`test/features/vorgang_starten/mandant_uebernahme_test.dart`

**Fallstricke**

- Der Prefill füllt das Formular nur aus — Captcha und Absenden macht der Anwalt selbst im
  sichtbaren Browserfenster (`receiveTimeout` 3 min statt der globalen 3 s). Nicht wegautomatisieren.
- Die laufende Auftragsnummer wird hier nur gelesen, nie erhöht: hochgezählt wird sie erst beim
  Abschluss des Vorgangs (`POST /api/Vorgaenge/abschliessen`, atomar im Backend).
- Die Referenz-Vorschau baut sich aus Auftragsnummer/Jahr/Abteilung/Gegner-Kennzeichen, bis der
  Nutzer sie einmal von Hand ändert — ab dann friert `_referenzManuallyEdited` die Automatik ein,
  bis „zurücksetzen" gedrückt wird.
- Das Rechtsgebiet schaltet mehr als Sichtbarkeit: `_applyUnfallValidators` setzt Pflichtfelder zur
  Laufzeit um, außerhalb Verkehrsrecht entfällt der Kennzeichen-Teil der Referenz, die Unfallfelder
  werden als `null` persistiert und es läuft kein Prefill.
- `MandantErkennung` schlägt Registereinträge nur vor, die Übernahme bleibt ein Klick; jede Anlage
  oder Änderung läuft vorher durch `MandantUebersichtDialog` — wird der abgebrochen, wird auch der
  Vorgang nicht gespeichert.
- Der lange Rest steht in `FALLSTRICKE.md` daneben: Reihenfolge im Speicherpfad, die drei Zustände
  mit gespeichertem Mandanten (sonst 409-Sackgasse) und warum Tests kein `pumpAndSettle` vertragen.
- `registriereAnfrage` ist ein Upsert über die Referenz: dieselbe Referenz erneut speichern
  aktualisiert nur die hier erfassten Felder und behält Antwort- und Dokumentdaten.
