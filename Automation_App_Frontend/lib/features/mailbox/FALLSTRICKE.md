# Posteingang und Zentralruf-Auswertung

Der allgemeine Posteingang liest alle Nachrichten des eingestellten Ordners (Standard `INBOX`).
Die Liste holt höchstens 50 Kopfdatensätze, ohne Mailtexte oder Anhänge. „Ältere“/„Neuere“ ersetzt
die Seite; im Speicher bleiben eine Seite, ein geöffneter Text und die kleinen Blätterkennungen.
Ein Cursor enthält Konto-/Ordnerkennung, UIDVALIDITY und die UID der ältesten angezeigten Mail.
Der nächste Abruf sucht deren aktuelle Position binär mit einzelnen UID-Abfragen. Damit bleiben
Seiten bei neuen oder zwischen zwei Abrufen gelöschten Mails stabil, ohne die ganze UID-Liste zu laden.
Löschungen während eines Abrufs führen zu einer wiederholbaren Fehlermeldung.

Der Text wird erst beim Öffnen geladen, bevorzugt als Nur-Text, sonst aus HTML in Text umgewandelt.
Externe Bilder werden nicht abgerufen. Textteile über 256 KiB werden mit Hinweis auf den Webmailer
abgewiesen; Anhänge erscheinen nur mit Namen. Sie werden in dieser Ansicht nicht heruntergeladen.
Es gibt keine Offline-Kopie des allgemeinen Posteingangs und keine Änderung der Gelesen-Markierung.

`messagesChanged` meldet unabhängig vom Zentralruf-Filter eine Änderung. Die erste Seite wird
entprellt nachgeladen, sofern keine Nachricht geöffnet ist; sonst erscheint ein Hinweis zum Laden.
Nach SignalR-Reconnect wird ebenfalls nachgeladen. Als Rückfall aktualisiert die sichtbare erste
Seite ohne geöffneten Text einmal pro Minute. Der Posteingang ist auch bei ausgeschalteter
Zentralruf-Überwachung manuell abrufbar. Abgebrochene/veraltete HTTP-Antworten verändern den neuen
Zustand nicht; der Dienst begrenzt gleichzeitige IMAP-Abrufe und die Wartezeit.

Die Zentralruf-Auswertung behält ihren bisherigen Ablauf:

- Der Hub überträgt keine Nutzdaten: `replyReceived`/`statusChanged` lösen nur
  `MailboxInboxCubit.refresh()` aus; neue Felder gehören ins `ReceivedReplyDto`.
- `MailboxHub.ensureConnected()` behandelt einen fehlgeschlagenen Aufbau als best-effort.
  Die Zentralruf-Liste lädt nach einer reinen Hub-Trennung erst beim nächsten Signal nach.
- Zentralruf-Treffer werden ausschließlich mit `includeAcknowledged: false` geladen. Nach
  `acknowledge` verschwinden sie aus dieser Liste, bleiben aber in der Datenbank. Die Mail selbst
  bleibt im allgemeinen Posteingang sichtbar, solange sie auf dem Server liegt.
- `acknowledge` sendet kein SignalR-Signal; Dashboard und Postfach halten eigene Factory-Cubits.
  Die Dashboard-Kachel aktualisiert sich daher erst mit dem nächsten `refresh()`.
- `ReceivedReply.zuordnungVermutet` wird nicht gelesen; `MailboxVorgangZuordnung` rechnet lokal neu.
- Microsoft-Anmeldung braucht `receiveTimeout: 6 Minuten` (Browser-Anmeldefenster: 5 Minuten).
- `MailboxVersandLeiste` gibt Vorgang und `reply.data` mit: Vor Übernahme steht die Versichereradresse
  nur in der Antwort. Der Dashboard-Sprung öffnet weiterhin direkt den Bereich Zentralruf-Antworten.
- Der Monitor holt beim Wiederverbinden weiterhin die letzten `InitialScanCount` Kopfdatensätze
  für die automatische Auswertung nach (Standard 20). Ältere Mails sind unabhängig davon über
  den allgemeinen Posteingang erreichbar. Vollständige Nachrichten lädt der Monitor erst nach
  dem Betreffvergleich, höchstens eine gleichzeitig; die Kopfzeilen werden in 50er-Paketen gelesen.
