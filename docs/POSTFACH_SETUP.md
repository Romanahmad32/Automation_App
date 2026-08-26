# Postfach anbinden — welcher Weg gilt?

Die App verbindet sich **direkt mit dem Mailserver**, nicht mit einem Mailprogramm. Ein
Webmailer im Browser und ein Outlook auf dem Rechner sind nur zwei Fenster auf dasselbe
Postfach; die App wird ein drittes. Die Frage „Webmailer oder Outlook anbinden?" hat deshalb
keine Antwort — die einzige Frage ist: **wo liegt das Postfach?**

Genau daran hängt auch der Anmeldeweg: Microsoft hat IMAP mit Passwort im September 2024
abgeschaltet, andere Anbieter kennen kein OAuth für Fremdprogramme.

## 1. Feststellen, wo das Postfach liegt

Der MX-Eintrag der Domain sagt es verbindlich (PowerShell, `<domain>` ersetzen):

```powershell
Resolve-DnsName -Name <domain> -Type MX | Select-Object NameExchange
```

| MX zeigt auf | Postfach liegt bei | Weg |
|---|---|---|
| `mx**.ionos.de`, `*.kundenserver.de`, `*.perfora.net` | 1&1 / IONOS | **A — IMAP mit Passwort** |
| `*.mail.protection.outlook.com` | Microsoft 365 | **B — Microsoft-Anmeldung** |
| `*.google.com`, `*.googlemail.com` | Google Workspace / Gmail | **A**, mit App-Passwort |
| etwas anderes | dieser Anbieter | **A**, Serverdaten beim Anbieter erfragen |

Ohne DNS geht es auch in Outlook: *Datei → Kontoeinstellungen → Kontoeinstellungen*. Die Liste
hat eine Spalte **„Typ"** — `IMAP/SMTP` heißt Weg A, `Microsoft Exchange` heißt Weg B. Steht dort
`POP/SMTP`, siehe „Fallstricke" ganz unten: so bekommt die App die Antworten nie zu sehen.

## 2. Weg A — IMAP mit Passwort

Für 1&1/IONOS gelten diese Werte; die Voreinstellung in der Oberfläche trägt sie mit einem Klick
ein, damit niemand Servernamen abtippt:

| | Wert |
|---|---|
| IMAP-Host | `imap.ionos.de` |
| Port / Verschlüsselung | 993, SSL |
| Benutzername | die **vollständige** E-Mail-Adresse |
| Passwort | das Passwort des Postfachs (1&1 kennt kein App-Passwort-Konzept) |
| SMTP | wird abgeleitet (`smtp.ionos.de`, Port 587 STARTTLS) — **nichts einzutragen** |

In der App: *Einstellungen → Postfach-Zugang* → Anmeldeweg **„IMAP mit Passwort"** →
Voreinstellung **„1&1 / IONOS"** → Adresse und Passwort eintragen → Überwachung einschalten →
speichern. Die Überwachung verbindet sich sofort mit den neuen Werten neu.

Bei **Gmail** stattdessen 2-Faktor-Authentifizierung aktivieren und unter
<https://myaccount.google.com/apppasswords> ein App-Passwort erzeugen — dieses gehört ins
Passwortfeld, nicht das Kontopasswort.

Passt der abgeleitete SMTP-Server bei einem anderen Anbieter nicht, lässt er sich in
`AutomationService/AutomationService/appsettings.json` unter `EmailVersand:SmtpHost`
überschreiben.

## 3. Weg B — Outlook.com / Microsoft 365

Nur wenn das Postfach wirklich bei Microsoft liegt. Dieser Weg braucht eine einmalige
Azure-App-Registrierung durch den Entwickler; die vollständige Anleitung steht in
[`docs/OUTLOOK_SETUP.md`](OUTLOOK_SETUP.md).

## 4. Wo der Zugang gespeichert wird

`%APPDATA%\AutomationService\mailbox_config.json`. Das Passwort liegt dort **DPAPI-verschlüsselt**
(`PasswortSchutz`), gebunden an die Windows-Anmeldung des Anwenders:

- Eine ältere Datei mit Klartext-Passwort wird beim ersten Start stillschweigend umgezogen.
- Kopiert man die Datei in ein anderes Windows-Benutzerkonto, ist das Passwort dort unlesbar —
  die App meldet das und der Zugang wird einmal neu eingegeben.
- Das Backend liefert das gespeicherte Passwort nie wieder aus; das Feld in der Oberfläche
  bleibt leer und „leer lassen" heißt „unverändert".

Versendet wird über **denselben** Zugang (§4.7): Wer empfangen kann, kann auch senden — ein
zweiter Satz Zugangsdaten wäre eine zweite Stelle, die veraltet. Die gesendete Nachricht trägt
die App danach per IMAP in „Gesendet" nach, außer der Anbieter tut es selbst (Gmail).

## Fallstricke

- **POP3 statt IMAP.** Holt Outlook die Mails per POP3 mit „Kopie vom Server löschen", sind sie
  weg, bevor die Überwachung sie sieht — die Zentralruf-Antwort käme nie an. Outlook auf IMAP
  umstellen.
- **Passwortwechsel beim Anbieter.** Die Überwachung meldet dann einen Anmeldefehler; das neue
  Passwort gehört einmal in die Einstellungen.
- **Zwei Programme am selben Postfach sind unkritisch.** Die Überwachung ändert nichts am
  Postfach: keine Gelesen-Markierung, kein Verschieben, kein Löschen. Umgekehrt erscheint die
  von der App gesendete Mail auch im „Gesendet" des Mailprogramms.
- **Anhänge.** Zusammen höchstens 20 MB (`EmailVersand:MaxAnhangGesamtMb`); größere Nachrichten
  weisen die üblichen Postfächer ab.
