# vorgaenge — Lebenszyklus und Sachgebiete-Register

**Zweck:** Der Vorgang bündelt je Auftrag Mandant, Referenz, Zentralruf-Antwort und Dokument und
führt ihn durch Angefragt → Beantwortet → Erstellt → Abgelegt → Versendet. Zwei Tabs: „Vorgänge
verwalten" (Pflege, Tab 7) und das Sachgebiete-Register der abgeschlossenen Vorgänge (Tab 6).
**Anforderung:** `REQUIREMENTS.md` §3, §4.8, §6.2
**Einstieg:** `presentation/blocs/vorgang_cubit.dart`
**Zustand:** `VorgangCubit` (`presentation/blocs/vorgang_cubit.dart`, `@lazySingleton` — der
app-weite Bestand, den auch word_automation, mailbox, zentralruf_reply und dashboard lesen) ·
`VorgangPersistenzFehlerCubit` · `VorgangNavigationSignal` (beide `presentation/blocs/`) ·
`LetzteVersaendeCubit` aus **email_versand** für die Versandzeile der Liste
**Domain:** Entities `Vorgang`, `VorgangStatus`, `ReferenzTeile`, `Rechtsgebiet`; Port
`VorgangRepository`; Dienste `AntwortKonflikte`, `VorgangPrefillMatcher`, `VorgangRueckfluss`,
`VorgangVollstaendigkeit`, `VorgangWartezeit`, `RegisterWordExporter`, `MandantAnschrift`. Keine UseCase-Klassen.
**Backend:** `Features/Vorgaenge/` · `GET|PUT /api/Vorgaenge`, `DELETE /api/Vorgaenge?referenz=`,
`POST /api/Vorgaenge/abschliessen?referenz=`, `POST /api/Vorgaenge/referenz?von=&nach=`
**Tests:** `test/features/vorgaenge/` — u. a. `vorgang_cubit_test.dart`, `vorgang_test.dart`,
`antwort_konflikte_test.dart`, `register_tabelle_test.dart`

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
- Das Register ist kein eigener Bestand: `RegisterPage` filtert `status == versendet`. Die laufende
  Nummer der Zeile stammt aus der geparsten Referenz (`ReferenzTeile`), nicht aus dem Zähler — der
  Abschluss zählt für den *nächsten* Vorgang hoch.
- `RegisterWordExporter` hat nur die Platzhalter-Umsetzung `NichtVerfuegbarerRegisterWordExporter`
  (`verfuegbar == false`, `exportiere` wirft). Der Export-Knopf ist deaktiviert — und sein
  `onPressed` ist auch im Zweig `verfuegbar == true` ein leerer Callback: die Handlung fehlt noch.
- `Vorgang.copyWith` verknüpft jedes Feld mit `??`: Ein gesetzter Wert lässt sich damit nicht auf
  null zurücksetzen (Absicht — eine erneute Anfrage darf erfasste Antwortdaten nicht verlieren).
- `VorgangVersandZeile` liest den Versandstand aus **email_versand** (ein Abruf für alle Zeilen,
  Klick öffnet `VersandProtokollDialog`); leer heißt „nichts versendet **durch die App**" (§4.8).
