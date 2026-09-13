# Posteingang und Zentralruf-Auswertung

Der allgemeine Posteingang liest alle Nachrichten des eingestellten Ordners (Standard `INBOX`).
Ein Abruf holt höchstens 50 Kopfdatensätze samt Envelope (Absender, Empfänger, Message-Id) und
BODYSTRUCTURE (für die Büroklammer und die Anzahl der Anhänge) — **kein** Mailtext, **kein**
`PreviewText`. `AutomationService.Tests.PosteingangTests` prüft das noch immer, nur die Erwartung
ist auf `Body | PreviewText` eingeengt (statt zusätzlich `BodyStructure` zu verbieten): BODYSTRUCTURE
beschreibt nur die Struktur einer Nachricht und lädt keinen Inhalt — das war eine bewusst geänderte
Testerwartung (Entscheidung des Masters zu Issue #134, Begründung im Commit).

**Anhängen statt Seitentausch.** `PosteingangCubit.aeltere()` hängt die nächste Seite an
`state.eintraege` an, statt sie wie früher zu ersetzen — Tagesgruppen und Filter brauchen alle
bisher gesehenen Zeilen gleichzeitig. Gedeckelt bei `PosteingangState.deckel = 500` (10 Seiten):
Darüber lädt „Ältere laden" nicht mehr nach, und die Fußzeile sagt, dass ältere Nachrichten nur
noch im Mailprogramm liegen. Ein Cursor bleibt trotzdem, was er war — Konto-/Ordnerkennung,
UIDVALIDITY und die UID der ältesten angezeigten Mail, binär gegen die aktuelle Position gesucht,
damit neue oder zwischendurch gelöschte Mails die Seiten nicht verschieben.

**Die Message-Id ist die Brücke zur erfassten Zentralruf-Antwort.** `ReceivedReply.mailSchluessel`
(Backend-Feld `mailSchluessel`, aus `ReceivedReplyEntity.DedupeKey`) und
`PosteingangEintrag.messageId` (aus `Envelope.MessageId`) werden über
`normalisiereMailSchluessel` verglichen — getrimmt, ohne spitze Klammern, kleingeschrieben.
`PosteingangCubit.merkeZentralruf(messageIds)` bekommt die Schlüssel der noch **offenen** Treffer
von `MailboxInboxCubit` (das nur `includeAcknowledged: false` lädt); ein Schlüssel, der einmal
gemeldet wurde und dann fehlt, gilt als übernommen (`PosteingangState.zentralrufFuer`). **Der
Rückfall greift hier nicht**: Ist `mailSchluessel` `null` (Altbestand vor diesem Feld, oder der
Rückfallschlüssel `uidvalidity:uid` des Backends passt nicht zu einer Message-Id), erscheint die
Zeile ohne Zentralruf-Chip — sie bleibt trotzdem über den allgemeinen Posteingang lesbar.

**Zwischenlager `Anhaenge/Posteingang/<Konto>/<Uid>/`, 14 Tage.** Derselbe Wurzelordner wie bei
den Anhängen einer erfassten Antwort (`AntwortAnhaenge`) — der bestehende Aufräumer
(`AnhangAblage.AltesLoeschen` in der Versand-Slice, rekursiv, 14 Tage) räumt hier ohne jede
Änderung mit ab. Der Posteingang ruft ihn **nicht** selbst auf (`SliceIsolationTests` verbietet den
Verweis `MailboxMonitor` → `EmailVersand`); er benutzt `AppDataPaths`/`PosteingangZwischenlager`
direkt. Grenzen: **30 MB je Anhang** (`PosteingangAnhaenge.MaxAnhangBytes`), **50 MB je
Nachrichtenordner** (`PosteingangZwischenlager.MaxOrdnerBytes`, dieselbe Zahl wie bei
`AntwortAnhaenge`) und **50 MB je `.eml`** (`PosteingangNachrichtAblage.MaxEmlBytes`) — jede
Überschreitung liefert **409/413** (`PosteingangException`) mit deutscher Meldung, im Frontend als
`Rueckmeldung`-Fehler. Liegt eine Datei schon (gleicher Name, gleiche Größe), wird sie nicht neu
geholt. **Nur ein Download gleichzeitig**: `PosteingangCubit._ladeInsZwischenlager` verwirft einen
zweiten Aufruf während eines laufenden sofort mit `null`, statt den ersten zu stören — die eine
IMAP-Verbindung des `PosteingangDienst` (`SemaphoreSlim(1,1)`) ließe ohnehin nur einen Abruf zu und
würde sonst für bis zu 45 s auch das Blättern blockieren; die Listenknöpfe bleiben währenddessen
bedienbar, nur der Ring an der Zeile zeigt den laufenden Download.

**HTML wird serverseitig entschärft, das Frontend lädt trotzdem nichts nach.**
`PosteingangHtmlFilter.FuerAnzeige` entfernt `<script>`/`<style>`/`<iframe>`/`<object>`/`<embed>`/
`<link>`/`<meta http-equiv>` samt Inhalt, jedes `on…="…"`-Attribut und jeden nachladenden Verweis
(`src`/`background`/`url(...)` mit `http:`/`https:`/`//`, dazu `cid:`) — das Element bleibt stehen
und trägt danach `data-blockiert="1"`; der Dienst meldet das zusätzlich als eigenes Feld
`bilderBlockiert` im Inhalt. `PosteingangHtmlAnsicht` zeigt den Hinweis „Externe Bilder
werden nicht geladen." nur, wenn dieses Feld gesetzt ist (kein Suchen im HTML-Text), und ersetzt **zusätzlich** jedes `<img>`
über `HtmlWidget.customWidgetBuilder` durch ein Platzhaltersymbol — doppelt gesichert, falls ein
`src` einmal am Filter vorbeikäme. Nicht `SignaturHtmlFilter` aus `email_versand` wiederverwenden
(Slice-Grenze) — anderer Zweck (abgewählte Bilder der eigenen Signatur), eigene Datei als Vorlage
gelesen.

**Vorgangsbezug — Vorschlag, nicht Entscheidung.** `VorgangsbezugErkenner` ändert nie einen
Vorgang; er liest `List<Vorgang>` (aus `VorgangCubit`) und liefert `null` oder einen
`Vorgangsbezug`. Reihenfolge: Zeichen im Betreff (sicher) → Schadennummer im Betreff (sicher) →
Absenderadresse bei einem noch offenen Vorgang (vermutet). **Mehrdeutig zählt als „kein Bezug"**:
Treffen auf derselben Stufe mehrere Vorgänge zu, liefert die Stufe `null` — die Suche weicht dabei
**nicht** auf die nächste, schwächere Stufe aus, sie endet dort. Ein falsch zugeordneter
Schriftsatz kostet mehr als ein fehlender Vorschlag. Schadennummer heißt hier
`vorgang.antwort?.versicherungsscheinNr`, getrimmt und **mindestens 6 Zeichen** lang — kürzere
Zeichenfolgen stecken zufällig in vielen Betreffzeilen. „Nicht zuordnen“
(`PosteingangCubit.nichtZuordnen`) gilt **nur für die laufende Sitzung**: Es unterdrückt den
Vorschlag in `PosteingangState.bezugFuer`, ändert aber nichts im Vorgang und am Erkenner — nach
einem Neustart erscheint derselbe Vorschlag wieder.

Der Text wird erst beim Öffnen geladen, bevorzugt als Nur-Text, sonst aus HTML gewandelt (`html`
zusätzlich, wenn vorhanden). Textteile über 256 KiB werden mit Hinweis auf den Webmailer
abgewiesen, Text und HTML getrennt. Es gibt keine Offline-Kopie des allgemeinen Posteingangs und
keine Änderung der Gelesen-Markierung.

`messagesChanged` meldet unabhängig vom Zentralruf-Filter eine Änderung. Die erste Seite wird
entprellt nachgeladen, sofern keine Nachricht geöffnet ist; sonst erscheint ein Hinweis zum Laden.
Der Posteingang ist auch bei ausgeschalteter Zentralruf-Überwachung manuell abrufbar. Abgebrochene/
veraltete HTTP-Antworten verändern den neuen Zustand nicht.

Die Zentralruf-Auswertung behält ihren bisherigen Ablauf:

- Der Hub überträgt keine Nutzdaten: `replyReceived`/`statusChanged` lösen nur
  `MailboxInboxCubit.refresh()` aus; neue Felder gehören ins `ReceivedReplyDto`.
- `MailboxHub.ensureConnected()` behandelt einen fehlgeschlagenen Aufbau als best-effort.
- Zentralruf-Treffer werden ausschließlich mit `includeAcknowledged: false` geladen. Nach
  `acknowledge` verschwinden sie aus dieser Liste (und damit aus `zentralrufOffen`), bleiben aber
  in der Datenbank. Die Mail selbst bleibt im allgemeinen Posteingang sichtbar, solange sie auf
  dem Server liegt.
- `acknowledge` sendet kein SignalR-Signal; Dashboard und Postfach halten eigene Factory-Cubits.
- `ReceivedReply.zuordnungVermutet` wird nicht gelesen; `MailboxVorgangZuordnung` rechnet lokal neu.
- Microsoft-Anmeldung braucht `receiveTimeout: 6 Minuten` (Browser-Anmeldefenster: 5 Minuten).
- Der Monitor holt beim Wiederverbinden weiterhin die letzten `InitialScanCount` Kopfdatensätze für
  die automatische Auswertung nach (Standard 20). Ältere Mails sind unabhängig davon über den
  allgemeinen Posteingang erreichbar.

**Auswahl-Vokabular** (Issue #134, `test/architecture/auswahl_sichtbar_test.dart`): Der
Bereichsumschalter Posteingang/Gesendet ist ein `SegmentedButton`; die Filterreihe
[Alle | Zentralruf (n) | Mit Vorgang | Ohne Bezug] sind `ChoiceChip` (genau eine Wahl gilt), **kein**
`FilterChip`.
