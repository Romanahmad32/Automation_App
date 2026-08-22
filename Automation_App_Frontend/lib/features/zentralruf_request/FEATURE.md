# zentralruf_request — Zentralruf-Onlineformular vorbefüllen

**Zweck:** Stößt die Vorbefüllung des Online-Anfrageformulars des Zentralrufs an; das Backend
öffnet dafür einen sichtbaren Browser und trägt Kanzlei-, Mandanten- und Unfalldaten ein. Captcha
und Absenden erledigt der Anwalt selbst. Nicht hier: die Erfassung der Mandatsdaten und die Anlage
des Vorgangs (`vorgang_starten`) sowie die Auswertung der Antwortmail (`zentralruf_reply`).
**Anforderung:** `REQUIREMENTS.md` §4.2
**Einstieg:** `data/datasources/zentralruf_datasource.dart`
**Zustand:** keiner — das Feature hat keine Presentation-Schicht. Aufgerufen wird es aus
`VorgangStartenBloc` (`lib/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart`).
**Domain:** `ZentralrufRequest` (mit `ZentralrufAnfrager`, `ZentralrufGeschaedigter`),
`ZentralrufPrefillResult`; UseCase `PrefillZentralrufForm`
**Backend:** `Features/ZentralrufAutomation/` · `POST /api/Zentralruf/prefill`
**Tests:** `test/features/vorgang_starten/vorgang_starten_bloc_test.dart` (über einen Fake des
UseCase; für das Feature selbst gibt es keinen eigenen Test)

**Fallstricke**

- Der Browser startet absichtlich sichtbar (`headless: false` in `ZentralrufAutomationService`),
  und der Playwright-Kontext bleibt nach dem Vorbefüllen offen. Das Backend klickt „Absenden"
  nicht und löst kein Captcha — dieser Haltepunkt ist gefordert (§4.2) und darf nicht
  wegautomatisiert werden.
- Reihenfolge in `VorgangStartenBloc._onSpeichereVorgang`: erst Mandant auflösen, dann Prefill, erst
  danach `registriereAnfrage`. Die vom Backend zurückgegebene `referenz` überschreibt die
  eingetippte und ist die, mit der der Vorgang angelegt wird — an ihr hängt später die Zuordnung
  der Antwort. Schlägt das Prefill fehl, bricht der Ablauf ab, bevor ein Vorgang entsteht.
- Der Aufruf setzt `receiveTimeout: 3 Minuten`: Browserstart und die einmalige
  Playwright-Nachinstallation dauern länger als das globale Dio-Timeout.
- Das Referenzformat `Nr/Jahr Abteilung_Kennzeichen` baut das Backend
  (`ZentralrufAutomationService.BuildReferenz`); `auftragsjahr: 0` bedeutet „aktuelles Jahr", eine
  mitgeschickte `referenz` hat Vorrang. Im Frontend nicht nachbauen.
- `anfrager: null` heißt nicht „leer", sondern „Backend nimmt seine Werte aus `appsettings.json`";
  auch einzelne Leerfelder fallen dort feldweise zurück (`ResolveAnfrager`). Ein leerer Kanzleiname
  aus den Einstellungen löscht also nicht, sondern lässt den Fallback gewinnen.
- `filledFields`/`skippedFields` liefert das Backend, das Frontend wertet sie derzeit nirgends aus:
  `VorgangStartenBloc` nimmt nur `referenz`. Wer die übersprungenen Felder anzeigen will, muss sie
  erst durch Bloc und State durchreichen — sie fehlen nicht, sie werden verworfen.
