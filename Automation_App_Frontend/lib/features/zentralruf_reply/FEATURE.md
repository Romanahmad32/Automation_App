# zentralruf_reply — Antwortmail auswerten und übernehmen

**Zweck:** Wertet die Antwortmail des Zentralrufs aus (eingefügt, als `.txt`/`.eml` geladen oder
per Postfach erfasst), lässt den Anwalt die erkannten Versicherer- und Vorgangsdaten prüfen und
korrigieren und übernimmt sie in einen Vorgang. Nicht hier: das Stellen der Anfrage
(`zentralruf_request`) sowie Liste, Status und Quittieren der Treffer (`mailbox`).
**Anforderung:** `REQUIREMENTS.md` §4.3
**Einstieg:** `presentation/widgets/vorgangsdaten_form.dart`
**Zustand:** `ZentralrufReplyBloc` (`presentation/blocs/zentralruf_reply_bloc.dart`) — nur der
Parse-Vorgang; die editierten Feldwerte hält `VorgangsdatenForm` im eigenen State.
**Domain:** `ZentralrufReplyData`, `ZentralrufReplyInput`, `ZentralrufReplyParseResult`
(`domain/entities/zentralruf_reply_data.dart`); UseCase `ParseZentralrufReply`
**Backend:** `Features/ZentralrufAutomation/` · `POST /api/Zentralruf/antwort/parse`
**Tests:** `test/features/zentralruf_reply/versicherer_ergaenzung_test.dart`,
`test/features/vorgaenge/antwort_konflikte_test.dart`

**Fallstricke**

- Das Feature hat keine eigene Seite und keine Route: `VorgangsdatenForm` und `ManualReplyInput`
  hängen in `MailboxDetailPane` des Postfachs. Manueller und automatischer Weg laufen bewusst
  durch dasselbe Formular — jede Änderung wirkt auf beide.
- Zuordnung in genau dieser Reihenfolge: exakter Referenztreffer (`VorgangCubit.findeZuReferenz`)
  vor dem Fallback über Gegner-Kennzeichen + Unfalldatum (`findeWahrscheinlichenVorgang`, nur bei
  genau einem Kandidaten im Status „Angefragt"). Der Fallback ist eine Vorauswahl mit Hinweis
  („wahrscheinliche Zuordnung"); die Bestätigung durch den Anwalt darf nicht wegfallen.
- Widersprechen Antwortwerte bereits erfassten Vorgangsdaten, zeigt
  `MailboxInboxView._gemeinsamUebernehmen` vor der Übernahme `AntwortKonflikte.finde` +
  `AntwortKonfliktDialog` (beide in `vorgaenge`). Bricht der Anwalt dort ab, wird nichts
  übernommen und der Treffer bleibt offen — kein `acknowledge`.
- Wird die Referenz von Hand geändert, verwirft `_bearbeiteteDaten()` die zerlegten Bestandteile
  (`referenzAuftragsnummer`, `-Jahr`, `-Abteilung`, `-Kennzeichen`) absichtlich: sie stammen aus
  dem Parser und passen dann nicht mehr.
- Bei Negativ-Antwort (`keinVersichererErmittelt`) und Zwischennachricht (`zwischennachricht`)
  bleibt „Übernehmen" gesperrt, bis ein Versicherername steht — bei der Zwischennachricht ist das
  Abwarten der Folgemail der Normalweg, nicht ein Fehler.
- Leere Versichererfelder füllt `VersichererErgaenzung` aus der Wissensbasis nach; sie überschreibt
  nie Eingetipptes und läuft nach `VersichererCubit.ladeErneut()` ein zweites Mal.
- Die Vorbelegung freier Vorlagenfelder saß früher hier (`VorgangsdatenFieldMatcher`) und kannte
  nur die Antwort. Sie liegt jetzt bei `FeldDatenquelleErkennung` (Feature `form_template_setup`),
  weil dieselbe Zuordnung auch den Vorgang und das Mandantenregister erreichen muss.
