## So installieren Sie das Update

Keine Sorge: Das Update ist unkompliziert, und Ihre Daten bleiben vollständig erhalten.

# ⬇️ [Hier klicken: Automation-App {VERSION} herunterladen](https://github.com/Romanahmad32/Automation_App/releases/download/v{VERSION}/Automation_App_Setup_{VERSION}.exe)

**In drei Schritten:**

1. **Schließen Sie die Automation-App und warten Sie danach einen Moment.**
   Beim Schließen legt die App noch eine Sicherung an. Ihre Vorgänge,
   Mandanten und Einstellungen bleiben erhalten; sie werden durch das Update
   nicht verändert.
2. **Klicken Sie oben auf den großen Link** (⬇️). Ihr Browser lädt die Datei
   herunter. Meldet Microsoft Edge, die Datei werde „nicht häufig
   heruntergeladen", klicken Sie bei der Datei auf die drei Punkte „…" und
   wählen „Beibehalten" – falls danach noch einmal nachgefragt wird, auf
   „Trotzdem beibehalten". Bei anderen Browsern wählen Sie sinngemäß „Behalten".
3. **Öffnen Sie die heruntergeladene Datei** (im Browser bei den Downloads, oder
   im Ordner „Downloads"). Zeigt Windows „Der Computer wurde durch Windows
   geschützt", klicken Sie auf „Weitere Informationen" und dann auf „Trotzdem
   ausführen". Diese Meldung kommt, weil die App nicht bei Microsoft registriert
   (signiert) ist – bei diesem Programm ist das unbedenklich. Klicken Sie im
   Installationsfenster auf „Weiter" bzw. „Installieren" und am Ende auf
   „Fertigstellen". Die App startet danach von selbst. Administratorrechte
   brauchen Sie dafür nicht.

**Dies ist das letzte Mal, dass Sie diese Schritte brauchen.** Ab Version
{VERSION} weist die App Sie selbst auf neue Versionen hin: Ein Klick auf „Jetzt
aktualisieren" genügt, und nach einem kurzen Neustart ist sie auf dem neuesten
Stand.

Wenn etwas nicht klappt, wenden Sie sich an Ihren Ansprechpartner für die App.

---

## Neu in {VERSION}

**Update mit einem Klick**
- Die App meldet selbst, wenn eine neue Version bereitsteht. „Jetzt
  aktualisieren" lädt und installiert sie; danach startet die App kurz neu.
  Der Umweg über die Download-Seite entfällt.

**Vollmacht**
- Zu jedem Vorgang lässt sich die Vollmacht aus den Mandantendaten befüllen,
  drucken und der Druck vermerken – ohne das Formular von Hand auszufüllen.
- Im Dialog sehen Sie vor dem Druck die Seite, den Drucker und nach dem Druck
  das Ergebnis. Die Vorschau folgt der gewählten Art (Unfall-, Bußgeld-,
  Strafsache); „In Word öffnen" ist ein Nebenweg, ohne den Dialog zu verlassen.
- Leere Felder erscheinen als Schreiblinie, damit sie von Hand ergänzt werden
  können, und der Dialog benennt sie.

**Postfach**
- Der Posteingang ist ein lesbares Postfach mit Vorgangsbezug: Zu jeder Mail
  schlägt die App den passenden Vorgang vor, mit Begründung. Es gibt Filter,
  einen Gesendet-Bereich und Handgriffe wie Antworten, „In die Akte" ablegen und
  „Beim Versand verwenden"; Anhänge lassen sich direkt öffnen.

**Mandanten**
- Die Akten eines Mandanten lassen sich direkt bei ihm öffnen, zuordnen und
  wieder lösen – ohne Umweg über den Zuordnungsstapel.
- Die Mandanten-Erkennung nennt das hinterlegte Kennzeichen, auf das sie sich
  stützt.

**Kennzeichen**
- Jede Schreibweise wird angenommen (etwa E-Scooter, Behörden, Ausland); die App
  rät nichts und schreibt nichts um. Beim Vergleich zählt die Schreibweise nicht,
  verschiedene Fahrzeuge bleiben aber verschieden.
- Beanstandet die App eine Eingabe, sagt sie, woran es liegt.

**Schreiben**
- Die Schreibennummer wird erst beim Speichern vergeben; der Hinweis „Zu diesem
  Vorgang gibt es bereits ein Schreiben" erscheint nur, wenn wirklich eines
  abgelegt ist.
- Ein angefangener Stand wird still wiederhergestellt; gesichert wird nur, was
  sich tatsächlich geändert hat.

**Technische Grundlagen**
- Die zugrunde liegenden Bausteine der App wurden aktualisiert, ohne dass sich
  die Bedienung ändert.

---

**Ihre Daten** (Mandanten, Vorgänge, Register) liegen unter
`%APPDATA%\AutomationService` und bleiben bei Update und Deinstallation
unangetastet. Steht mit dieser Version eine Änderung am Datenbankschema an,
legt die App vor der Umstellung automatisch eine Sicherung unter
`%APPDATA%\AutomationService\Sicherungen` ab.

**Voraussetzungen:** Windows 10/11 (64 Bit) und ein installiertes Microsoft Word
für die PDF-Vorschau. Eine .NET-Laufzeit muss *nicht* installiert werden — sie
steckt im Paket.
