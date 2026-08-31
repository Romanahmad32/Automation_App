# vorgaenge — Lebenszyklus und Sachgebiete-Register

**Zweck:** Der Vorgang bündelt je Auftrag Mandant, Referenz, Zentralruf-Antwort und Dokument und
führt ihn durch Angefragt → Beantwortet → Erstellt → Abgelegt → Versendet. Zwei Tabs: „Vorgänge
verwalten" (Pflege, Tab 7) und das Sachgebiete-Register aller Vorgänge (Tab 6), das zusätzlich als
Word- und PDF-Datei in einen einstellbaren Ordner geht (§6.2).
**Anforderung:** `REQUIREMENTS.md` §3, §4.8, §6.2
**Einstieg:** `presentation/blocs/vorgang_cubit.dart`
**Zustand:** `VorgangCubit` (`presentation/blocs/vorgang_cubit.dart`, `@lazySingleton` — der
app-weite Bestand, den auch word_automation, mailbox, zentralruf_reply und dashboard lesen) ·
`VorgangPersistenzFehlerCubit` · `VorgangNavigationSignal` · `RegisterSpiegelCubit` ·
`LetzteVersaendeCubit` aus **email_versand** für die Versandzeile der Liste
**Domain:** Entities `Vorgang`, `VorgangEntwurf`, `VorgangStatus`, `ReferenzTeile`, `Rechtsgebiet`,
`RegisterSpiegelErgebnis`; Ports `VorgangRepository`, `RegisterSpiegelRepository`; Dienste
`AntwortKonflikte`, `VorgangPrefillMatcher`, `VorgangRueckfluss`, `VorgangVollstaendigkeit`,
`VorgangWartezeit`, `RegisterFilter`, `MandantAnschrift`. Keine UseCases.
**Backend:** `Features/Vorgaenge/` · `GET|PUT /api/Vorgaenge`, `PUT|DELETE /api/Vorgaenge/entwurf`,
`DELETE /api/Vorgaenge?referenz=`, `POST …/abschliessen|referenz|register/export`, `GET …/register/stand`
**Tests:** `test/features/vorgaenge/` — u. a. `vorgang_cubit_test.dart`, `vorgang_test.dart`,
`antwort_konflikte_test.dart`, `register_tabelle_test.dart`, `register_filter_test.dart`,
`register_spiegel_cubit_test.dart`

**Fallstricke**

- `ladeErneut()` überschreibt einen nicht leeren Zustand bewusst nicht (`if (state.isEmpty …)`) —
  Nachladen wirkt nur beim Start. Im Backend geänderte Vorgänge kommen darüber nicht herein.
- Die Referenz ist der fachliche Schlüssel: Sie ändert man nie per `upsertVorgang` (das legt einen
  zweiten Vorgang an), sondern über `aendereReferenz` → `POST /api/Vorgaenge/referenz` (409 =
  Zielreferenz vergeben).
- „Abschließen" nur über `VorgangCubit.abschliessen` → `POST …/abschliessen`: Status „versendet",
  `AbgeschlossenAm` und das Hochzählen von `KanzleiSettings.LaufendeAuftragsnummer` laufen dort in
  einer Transaktion (idempotent). `copyWith(status: versendet)` + Upsert sieht gleich aus, zählt
  aber nicht hoch. Der Knopf sitzt im Word-Assistenten (Schritt 3), nicht in „Vorgänge verwalten".
- Das Register ist kein eigener Bestand: `RegisterPage` leitet es aus den Vorgängen ab. Der Filter
  dort wirkt **nur auf die Ansicht**, die Datei folgt einer Einstellung — und die laufende Nummer
  kommt aus der Referenz, nicht aus dem Zähler. Alles drei in **`FALLSTRICKE.md`** daneben.
- `Vorgang.copyWith` verknüpft jedes Feld mit `??`: nicht auf null zurücksetzbar (Absicht — eine
  erneute Anfrage darf erfasste Antwortdaten nicht verlieren). Ausnahme: `entwurf` (Rückgabe-Aufruf).
- `VorgangVersandZeile` liest den Versandstand aus **email_versand** (ein Abruf für alle Zeilen,
  Klick öffnet `VersandProtokollDialog`); leer heißt „nichts versendet **durch die App**" (§4.8).
