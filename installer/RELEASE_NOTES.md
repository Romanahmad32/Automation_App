Windows-Installer der Automation-App {VERSION}.

## Neu in {VERSION}

**Register und Auftragsnummern**
- Die Kanzleihistorie ab 2018 lässt sich jahrgangsweise einlesen; Register und
  Vorgang hängen danach zusammen — auch beim Löschen.
- Die nächste Auftragsnummer wird aus dem Bestand vorgeschlagen statt aus dem
  Zähler in den Einstellungen. Eine schon belegte Nummer warnt, sperrt aber nicht.

**Vorgang starten**
- Das Rechtsgebiet wird nicht mehr eigens gewählt: Es folgt der Abteilung und
  bleibt änderbar.
- Das Kennzeichen wird aus den bekannten Werten gewählt, Datumsabstände sind
  einstellbar.

**Postfach**
- Der vollständige Posteingang ist sichtbar, nicht mehr nur die
  Zentralruf-Antworten.

**Schreiben und Vorlagen**
- RVG-Platzhalter sind auffindbar und vollständig; kein roher Platzhalter mehr
  im fertigen Brief.
- Der Dateiname des Schreibens folgt der Kanzlei-Konvention.
- Word-Vorlagen lassen sich in der App einrichten und bearbeiten; ein
  angefangenes Schreiben überlebt den Neustart.

**Mandanten**
- Der Import läuft in Arbeitspaketen, über die die App Buch führt.

**Arbeitsplatz und Sicherung**
- Alle App-Daten können in einem OneDrive-Ordner liegen; der Wechsel zwischen
  zwei Rechnern zeigt seinen Synchronisationsstand.
- Die Sicherung läuft während der Arbeit weiter und staffelt die Aufbewahrung
  nach Alter.

**Bedienung**
- Der Schriftgrad ist dreistufig wählbar.
- Meldungen erscheinen oben rechts, statt sich unter Dialoge zu schieben.
- Die Einstellungen passen sich der Fensterbreite an.

**Installation:** `Automation_App_Setup_{VERSION}.exe` herunterladen und ausführen.
Die Installation erfolgt je Benutzer und ohne Administratorrechte. Ein Update
wird einfach über die vorhandene Installation installiert.

**Deine Daten** (Mandanten, Vorgänge, Register) liegen unter
`%APPDATA%\AutomationService` und bleiben bei Update und Deinstallation
unangetastet. Steht mit dieser Version eine Änderung am Datenbankschema an,
legt die App vor der Umstellung automatisch eine Sicherung unter
`%APPDATA%\AutomationService\Sicherungen` ab.

**Voraussetzungen:** Windows 10/11 (64 Bit) und ein installiertes Microsoft Word
für die PDF-Vorschau. Eine .NET-Laufzeit muss *nicht* installiert werden — sie
steckt im Paket.

Windows zeigt beim Start des Installers eine SmartScreen-Warnung, weil die Datei
nicht signiert ist: „Weitere Informationen" → „Trotzdem ausführen".
