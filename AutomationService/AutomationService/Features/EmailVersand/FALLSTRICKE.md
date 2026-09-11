# EmailVersand — Fallstricke

Der lange Rest zum Absatz in [`AutomationService/CLAUDE.md`](../../../CLAUDE.md). Die Wegweiser-Datei
hat ein Budget, diese hier nicht: was in vier Zeilen nicht zu sagen war, steht ausgeschrieben hier.
Wer den Slice zum ersten Mal anfasst, liest zuerst den Absatz dort — hier steht, was einen beim
zweiten Griff erwischt.

Der Slice versendet die fertig verfasste Mail zum Vorgang (§4.7, `POST api/EmailVersand/senden`,
`GET api/EmailVersand/bereitschaft`) oder öffnet sie als Entwurf in Outlook.

## Direktversand über SMTP

Gesendet wird über **denselben** Zugang wie beim `MailboxMonitor`: `SmtpZugang.Aus` leitet den
Postausgang aus dem Posteingang ab, `EmailVersand:SmtpHost` überschreibt ihn.

**Alles oder nichts.** Zugang, Anhänge und Adressen werden geprüft, **bevor** verbunden wird
(`AnhangPruefung`, `EmailNachrichtBauer`) — ein Fehler heißt: nichts ist hinausgegangen. Danach
trägt `GesendetOrdnerAblage` die Nachricht per IMAP in „Gesendet" nach, außer der Anbieter tut es
selbst (Gmail).

Was nach außen wirkt, hängt an drei Nähten, damit der Weg ausführbar prüfbar ist
(`VersandwegTests`): `ISmtpUebergabe` (Einlieferung), `IGesendetOrdnerAblage` (Kopie) und
`IMailboxConfigSource` (der Zugang). Die dritte Naht ist die wichtigste: Der `MailboxConfigStore`
dahinter liest im Konstruktor aus `%APPDATA%` — ein Test an der Klasse läse das echte Postfach.

## Entwurf in Outlook

Zweiter Weg: `POST api/EmailVersand/entwurf` öffnet die Nachricht als Entwurf in Outlook, sonst als
`.eml` (`EntwurfDatei`; `EntwurfOeffner` entscheidet).

`OutlookVerbindung` hält COM per **Late Binding** (kein PIA) auf einem **dauerhaften** STA-Thread —
sonst kostet jeder Entwurf den Outlook-Kaltstart; `POST api/EmailVersand/entwurf/vorwaermen` bezahlt
ihn, während der Anwalt tippt. **Jeder Einzelgriff wird losgelassen** (`ComFreigabe`), die Instanz
beim Herunterfahren auf ihrem STA-Thread — sonst bleibt outlook.exe stehen.

Im Outlook-Entwurf setzt Outlook seine eigene Signatur — deshalb hängt `KanzleiSignatur` die aus
den Einstellungen **nur** beim Direktversand an.

## Anhänge aus der offenen Outlook-Nachricht

`GET api/EmailVersand/outlook/anhaenge` holt die Anhänge der in Outlook offenen Nachricht
(`OutlookAuswahl`, ein Ordner **je Nachricht** nach EntryID, damit der zweite Griff dieselben Pfade
liefert statt „… (2).pdf") — der Ersatz für das Ziehen von Anhang zu Anhang: Outlook reicht sie als
*virtuelle* Dateien durch, nicht als Pfade.

Zurück geht ein `OutlookAnhaenge` mit Betreff, Absender und der Angabe, ob aus offenem Fenster oder
Liste gelesen — welche Nachricht gemeint war, entscheidet Outlook; ohne die Angabe sähe ein Griff in
die falsche Mail aus wie ein richtiger. `OutlookErreicht` trennt „Outlook schweigt" von „nichts
ausgewählt". `DELETE` darauf wirft eine geholte Datei weg (nur dieser Ordner, die Antwort-Anhänge
bleiben).

## Klassisches Outlook, oder gar keins

**Alle drei Outlook-Wege** (Entwurf, Anhang-Griff, Signatur-Übernahme) brauchen das *klassische*
Outlook — das neue (Store-App) meldet keine COM-Schnittstelle an und legt keine Signaturdateien ab,
alle drei täten dann wortlos nichts. `OutlookErkennung` sieht deshalb **beim Start** nach (Singleton
*und* `IHostedService`, sonst baut der Container sie erst beim ersten Klick), `GET
api/EmailVersand/outlook/stand` liefert den Grund im Klartext; der Direktversand über SMTP ist
unberührt.

## Versandprotokoll (§4.7)

`VersandProtokoll` hält je Vorgang fest, was hinausging — Zeitpunkt, Weg, Empfänger, Anhangnamen wie
versendet, ob die Kopie in „Gesendet" landete, und die Message-ID als Nachweis. Geschrieben **nach**
der Einlieferung, nie davor; ein Fehlschlag dabei hält den Versand nicht auf (die Mail ist ja beim
Empfänger). Adressiert über die *Referenz* statt einen Fremdschlüssel — die Slice darf `Vorgaenge`
nicht kennen. `VersandProtokollController` (`api/EmailVersand/protokoll`, `/letzte`) liest; die
Outlook-Übergabe steht darin als `OutlookEntwurf` und **nicht** als Versand (§4.8).

`AnhangAblage` räumt alle Zwischenlager nach 14 Tagen ab (`AnhangAufraeumService` beim Start) —
dieselbe Regel wie beim Arbeitsordner.

## Signatur (§4.7)

`GET signaturen` listet die in Outlook eingerichteten, `POST signaturen/uebernehmen` liest eine ein
— Nur-Text (`.txt`) **und** formatiert (`.htm` samt Bildern; `OutlookSignaturHtml` schneidet den
Rumpf und kürzt Bildverweise auf den blanken Dateinamen). Die Bilder liegen in `SignaturAblage`
(`%APPDATA%\AutomationService\Signatur`), das HTML in `KanzleiSettings.MailSignaturHtml`; `GET
signaturen/stand` meldet beides, `DELETE signaturen/format` wirft sie weg; **`GET
signaturen/vorschau?name=` liest ohne zu schreiben** (§4.7) — geschrieben wird erst über
`uebernehmen` beim Speichern.

`GET signaturen/bild?dateiname=&ausOutlook=&marke=` liefert **ein** Bild: ohne `ausOutlook` aus der
Ablage, mit ihm aus Outlooks Beiordner — das braucht die Vorschau, deren Bilder noch nirgends
abgelegt sind; `marke` wertet der Dienst nicht aus, sie macht nur die Adresse eindeutig (Begründung
an `SignaturMarke`).

Beim Versand baut `MailRumpf` daraus HTML **und** Text und hängt die Bilder als `cid:`-Ressourcen
an. Je Mail abwählbar (`EmailNachricht.OhneSignaturBilder`, `SignaturHtmlFilter`) — Word schreibt
jedes Bild **zweimal** (VML und als Bild-Element), und nur eins davon zu entfernen hiesse: abgewählt
und trotzdem sichtbar; das Muster für alle drei Fälle steht samt Begründung an `BildVerweis`. Die
Bilder zählen über `zusatzBytes` in `AnhangPruefung` zur Größengrenze, denn sie gehen im selben
Umschlag hinaus.

## Mail-Textvorlagen, Grußformeln, Anredebausteine (§4.7, §5.3)

`MailVorlagenController` (`api/MailVorlagen`, CRUD) über `MailVorlagenRepository`, Name eindeutig
(409). Ausgangsbestand ist das echte Kanzlei-Anschreiben; Abweichungen vom Original und das
erzwungene LF stehen an `MailVorlagenVorgabe`.

Daneben `GrussformelnController` (`api/Grussformeln`, CRUD): die Textbausteine für den Zusatzgruss —
eine Liste von Bausteinen, kein Merkmal von Personen (Art. 9 DSGVO), geseedet mit den beiden aus der
Kanzlei-Mail. Der Platzhalter heisst `{{Zusatzgruß}}` (bis 02.09.2026 `{{Grussformel}}`); wo er
steht, entscheidet die Vorlage — der Bestand hier weiss davon nichts.

Ebenso `AnredebausteineController` (`api/Anredebausteine`, CRUD): je Eintrag der **Anfang** einer
Anrede in drei Beugungsformen, Unique-Index über alle drei. Begründung an `AnredeBausteinEntity` und
`AnredeBausteineVorgabe`.
