Windows-Installer der Automation-App {VERSION}.

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
