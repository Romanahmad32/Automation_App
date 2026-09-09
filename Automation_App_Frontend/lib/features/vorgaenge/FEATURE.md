# vorgaenge — Lebenszyklus und Sachgebiete-Register

**Zweck:** Der Vorgang bündelt je Auftrag Mandant, Zeichen, Zentralruf-Antwort und Dokument und führt ihn durch Angefragt →
Beantwortet → Erstellt → Abgelegt → Versendet. Zwei Tabs: „Vorgänge verwalten" (Pflege, Tab 7) und das Sachgebiete-Register (Tab
6) aus Vorgängen **und** übernommener Registerhistorie, das zusätzlich als Word- und PDF-Datei in einen Ordner geht (§6.2).
**Anforderung:** `REQUIREMENTS.md` §3, §4.8, §6.2, §6.3
**Einstieg:** `presentation/blocs/vorgang_cubit.dart`
**Zustand:** `VorgangCubit` (`@lazySingleton` — der app-weite Bestand, den auch word_automation, mailbox, zentralruf_reply und
dashboard lesen) · `RegisterCubit` (Tab 6: Zeilen, Historienstand, Filter, Reihenfolge) · `RegisterSpiegelCubit` ·
`VorgangPersistenzFehlerCubit` · `VorgangNavigationSignal` · `VorgangHervorhebungSignal` · `LetzteVersaendeCubit` (email_versand)
**Domain:** Entities `Vorgang`, `VorgangEntwurf`, `VorgangStatus`, `ReferenzTeile`, `RechtsgebietWert`, `RegisterZeile`,
`RegisterHistorieStand`, `RegisterHistorieAenderung`, `RegisterSpiegelErgebnis`; Ports `VorgangRepository`,
`RegisterZeilenRepository`, `RegisterHistorieRepository`, `RegisterSpiegelRepository`, `RegisterPushNotifier`; Dienste
`AntwortKonflikte`, `VorgangPrefillMatcher`, `VorgangRueckfluss`, `VorgangVollstaendigkeit`, `VorgangWartezeit`, `RegisterFilter`,
`RegisterReihenfolge`, `VorgangJahrgang`, `MandantAnschrift`.
**Backend:** `Features/Vorgaenge/` + `Features/RegisterHistorie/` · `GET|PUT /api/Vorgaenge`, `PUT|DELETE /api/Vorgaenge/entwurf`,
`DELETE /api/Vorgaenge?referenz=&registerzeileBehalten=`, `POST …/abschliessen|referenz`, `POST …/register/export`,
`GET …/register/stand|zeilen`, `GET /api/RegisterHistorie/stand`, `GET|PUT|DELETE /api/RegisterHistorie/{id}`,
`GET …/register/nummern` (§6.3) → `RegisterNummernRepository`/`RegisterNummernStand`, auch von `vorgang_starten` gelesen ·
SignalR-Hub `/hubs/register`
**Tests:** `test/features/vorgaenge/` — u. a. `vorgang_cubit_test.dart`, `register_cubit_test.dart`,
`register_zeile_test.dart`, `register_tabelle_test.dart`, `register_view_bearbeiten_test.dart`

**Fallstricke**

- `ladeErneut()` überschreibt einen nicht leeren Zustand bewusst nicht (`if (state.isEmpty …)`) —
  Nachladen wirkt nur beim Start. Im Backend geänderte Vorgänge kommen darüber nicht herein.
- Die Referenz ist der Schlüssel, das **Zeichen** der angezeigte Name (`ZeichenText`, §4.2; beides
  in **`FALLSTRICKE.md`**). Die Referenz ändert man nie per `upsertVorgang` (das legt einen zweiten
  Vorgang an), sondern über `aendereReferenz` → `POST /api/Vorgaenge/referenz` (409 = vergeben).
- „Abschließen" nur über `VorgangCubit.abschliessen` → `POST …/abschliessen`: Status „versendet",
  `AbgeschlossenAm` und das Hochzählen von `KanzleiSettings.LaufendeAuftragsnummer` laufen dort in
  einer Transaktion (idempotent). `copyWith(status: versendet)` + Upsert sieht gleich aus, zählt
  aber nicht hoch. Der Knopf sitzt im Word-Assistenten (Schritt 3), nicht in „Vorgänge verwalten".
- Das Register ist kein eigener Bestand und wird seit #109 **im Backend gebaut** (`register/zeilen`,
  Vorgänge und Historie in einer Folge) — Sortierung, Zellen, Filterwirkung: **`FALLSTRICKE.md`**.
- `Vorgang.copyWith` verknüpft jedes Feld mit `??`: nicht auf null zurücksetzbar (Absicht — eine
  erneute Anfrage darf erfasste Antwortdaten nicht verlieren). Ausnahme: `entwurf` (Rückgabe-Aufruf).
- `VorgangVersandZeile` liest den Versandstand aus **email_versand** (ein Abruf für alle Zeilen,
  Klick öffnet `VersandProtokollDialog`); leer heißt „nichts versendet **durch die App**" (§4.8).
