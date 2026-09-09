# Zwischen Bürorechner und Laptop wechseln

Die App arbeitet auf jedem Rechner mit einer lokalen Datenbank. OneDrive transportiert
geprüfte Sicherungsdateien zwischen den Rechnern. Eine Übernahme ersetzt den gespeicherten
App-Bestand; getrennte Änderungen werden nicht automatisch zusammengeführt.

## Einmalig einrichten

1. Auf beiden Rechnern dieselbe aktuelle App-Version installieren und dasselbe passende
   OneDrive-Konto einrichten. Beide Rechner sollen unterschiedliche Windows-Rechnernamen haben.
2. In den Kanzleidaten unter **Gemeinsamer OneDrive-Ordner** auf beiden Rechnern denselben Ordner wählen,
   zum Beispiel `OneDrive – Kanzlei\Kanzlei App Daten`. Die App verwendet darunter
   `Sicherungen`, `Vorlagen` und `Register`, sofern unter **Erweiterte Einstellungen** keine Sonderpfade eingestellt sind.
   Aktive Abweichungen werden dort auch im zugeklappten Zustand angezeigt.
3. Auch den **Aktenstammordner** auf beiden Rechnern auf dieselbe synchronisierte Aktenablage
   einstellen. Bereits abgelegte Akten und Dokumente werden separat durch OneDrive übertragen.
4. Diese OneDrive-Ordner im Explorer auf beiden Rechnern mit **Immer auf diesem Gerät behalten**
   markieren. Postfach-Zugang und Anmeldung je Rechner einrichten; Passwörter und Tokens
   werden nicht in die gemeinsame Sicherung gepackt.

Die laufende Datei `%APPDATA%\AutomationService\automation.db` bleibt lokal. Den gesamten
internen AppData-Ordner nicht nach OneDrive verschieben.

Die OneDrive-Anzeigen und die lokale Verfügbarkeit erklärt Microsoft unter
[Dateien bei Bedarf](https://support.microsoft.com/en-us/office/save-disk-space-with-onedrive-files-on-demand-for-windows-0e6860d3-d9f3-4971-b321-7092438fb38e)
und [Bedeutung der Synchronisationssymbole](https://support.microsoft.com/en-us/onedrive/what-do-the-onedrive-icons-mean).

## Im Alltag

1. Eingaben speichern und unter **Einstellungen → Datensicherung → Arbeitsplatzwechsel & Synchronisierung** **Jetzt bereitstellen** wählen. Währenddessen zeigt die App,
   dass die Sicherung erstellt und im gemeinsamen Ordner abgelegt wird.
2. Vor dem Ausschalten im OneDrive-Symbol prüfen, dass die Synchronisierung abgeschlossen ist.
   Die App kann den erfolgreichen Upload in die Cloud nicht bestätigen.
3. Am anderen Rechner OneDrive synchronisieren lassen und die App öffnen. Ein verfügbarer
   Datenstand wird zur Übernahme angeboten. Trifft er später ein, erkennt die zentrale
   Statusprüfung ihn beim nächsten Abruf (alle 15 Sekunden oder über den Aktualisieren-Knopf).
4. Unter **Einstellungen → Datensicherung** **Stand übernehmen** wählen. Die App lädt und prüft die Datei, sichert den bisherigen
   Bestand und lädt nach erfolgreicher Übernahme die Ansichten neu. Offene ungespeicherte
   Eingaben vorher speichern. Eine Übernahme wird im gemeinsamen Ordner quittiert.

Zusätzlich stellt die App Änderungen alle 30 Minuten, beim Vorgangsabschluss und beim
Beenden bereit. Beim Beenden kann die Sicherung noch laufen, nachdem das Fenster geschlossen
wurde. Für einen unmittelbar anschließenden Rechnerwechsel deshalb **Jetzt bereitstellen**
verwenden und anschließend OneDrive abwarten. Unveränderte Inhalte erzeugen kein neues Archiv.

## Was die Anzeige bedeutet

| Anzeige | Bedeutung und nächster Schritt |
|---|---|
| Lokal gespeichert – Bereitstellung steht aus | Daten sind auf diesem Rechner gespeichert. Bei einem baldigen Wechsel jetzt bereitstellen. |
| Sicherung wird bereitgestellt | Die App baut die Datei und legt sie im gemeinsamen Ordner ab. |
| Bereitgestellt | Lokale Ablage erfolgreich. In den Einstellungen stehen Sicherungszeitpunkt, Datei und Empfangshinweis; den Cloud-Upload in OneDrive prüfen. |
| Warte auf die Übertragung | Ein anderer Rechner hat eine Sicherung angekündigt, die Datei fehlt hier noch oder hat noch nicht die erwartete Größe. |
| Stand verfügbar | Eine angekündigte Datei liegt vor. Beim Übernehmen werden ihre Prüfsummen und die Datenbank geprüft. |
| Unterschiedliche Änderungen | Beide Stände enthalten nicht gemeinsam übernommene Änderungen. Rechner und Zeitpunkt vergleichen; erst dann ausdrücklich einen Stand auswählen. |
| Status nicht prüfbar / Sicherung fehlgeschlagen | OneDrive und Ablageordner prüfen. Ein lokaler Speicherstand bedeutet noch keine erfolgreiche Übergabe. |

Bitte abwechselnd arbeiten. Offline-Arbeit und gleichzeitige Arbeit sind möglich, können aber
zu getrennten Ständen führen. Vor dem Ersetzen legt die App eine lokale Vor-Import-Sicherung an.
Abweichende lokale Word-Vorlagen werden weiterhin erhalten und als übersprungen gemeldet.

## Technischer Umfang und Prüfung

- ZIP: Datenbank, Word-Vorlagen, erfasste Mailanhänge und Prüfsummenmanifest. Aktenverweise
  unter dem eingestellten Aktenstamm werden auf den Zielrechner angepasst.
- Archive werden vollständig gebaut und erst danach veröffentlicht. SHA-256 und Dateigröße
  binden die Ankündigung an die konkrete Datei. Das ist eine Integritätsprüfung, keine
  Verschlüsselung oder digitale Signatur.
- Lokale Herkunftskennung und Vorgänger unterscheiden Datenänderungen von bloßen neuen
  Sicherungszeitpunkten. Die Bestätigung einer Übernahme gilt nur für die angezeigten Stände.
- Entpacken, Integritätsprüfung und Migration geschehen vor dem Tausch. SQLite Online Backup
  tauscht die Datenbank transaktional; bei abgefangenen Fehlern werden vorbereitete
  Dateiveränderungen zurückgenommen. Ein harter Rechnerausfall über mehrere Dateien ist
  keine dateisystemübergreifende Transaktion; die Vor-Import-Sicherung bleibt der Rückweg.
- Alte `.db`- und ZIP-Sicherungen bleiben lesbar. Ältere ZIPs besitzen keine neuen Prüfsummen
  und enthalten keine Mailanhänge. Auf beiden Rechnern die neue App-Version verwenden.

Vor dem produktiven Einsatz einen Wechsel mit Testdaten in beide Richtungen durchführen,
einschließlich einer verzögerten OneDrive-Übertragung, eines Mailanhangs und eines abgelegten
Dokuments. Die automatisierten Tests simulieren Dateien und zwei Datenbestände; sie ersetzen
keinen Test mit den tatsächlich eingerichteten OneDrive-Konten.
