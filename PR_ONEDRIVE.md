# OneDrive-Arbeitsplatzwechsel und transparenter Synchronisationsstand

Beim Wechsel zwischen Bürorechner und Laptop soll erkennbar sein, welcher Datenstand bereitgestellt wurde und welcher zur Übernahme vorliegt. Diese Änderung erweitert die Übergabe über einen gemeinsamen OneDrive-Ordner und verlegt die Bedienung unter Einstellungen → Datensicherung → Arbeitsplatzwechsel & Synchronisierung. Die dauerhafte Leiste über den App-Seiten entfällt; die zentrale Statusprüfung läuft weiterhin alle 15 Sekunden und beim Wiederaufnehmen.

- Die Einstellungen zeigen Sicherungszeitpunkt, Dateiname, lokale Änderungen, angebotenen Rechnerstand und letzte Statusprüfung. Sie erläutern die automatische Bereitstellung alle 30 Minuten, beim Vorgangsabschluss und beim Beenden. Eine lokale Ablage wird nicht als bestätigter OneDrive-Upload ausgegeben.
- Revisionen, Vorgänger und ein lokaler Fingerabdruck unterscheiden neue Inhalte von bloßen Sicherungszeitpunkten. Konflikte und Änderungen nach der Anzeige benötigen eine erneute, an den konkreten Stand gebundene Bestätigung.
- Sicherungsarchive enthalten Datenbank, Vorlagen, erfasste Anhänge und Prüfsummen. Importprüfung, portable Pfade, Vor-Import-Sicherung und der Schutz vor Schreibzugriffen aus veralteten Ansichten sichern die Übernahme ab. Router und Formulare werden anschließend neu aufgebaut.
- Einrichtung und Ablauf sind in `docs/ONEDRIVE_ARBEITSPLATZWECHSEL.md` beschrieben; API-Vertrag und Feature-Dokumentation sind aktualisiert.

## Prüfung

- Erfolgreich: 127 Frontend-Backup- und Architekturtests, einschließlich Hintergrundprüfung ohne sichtbare Leiste, deaktivierter Automatik ohne Ablageordner und schmalem Fenster bei großer Schrift.
- Erfolgreich: Frontend-Codegenerierung; generierter Stand und Sperrdatei unverändert; Formatierung von 956 Dart-Dateien ohne Änderungen.
- Frontend-Gesamtlauf beim Analysestart ohne weiteren Fortschritt beendet. Analyse und vollständige Frontend-Testsuite sind nicht bestätigt.
- Backend-Prüfkette vollständig erfolgreich: Build mit 0 Warnungen und 0 Fehlern, alle 613 Tests bestanden, Formatierung von Dienst und Tests geprüft.

## Vor Merge offen

- `SicherungsZeitgeber.ExecuteAsync` setzt beim Start den aktuellen Bestand als Vergleichswert. Nach einem zuvor fehlgeschlagenen Sicherungslauf oder Absturz können noch ungesicherte Änderungen dadurch bis zur nächsten Änderung oder zum Beenden liegen bleiben. Vor Merge die Startlogik gegen die letzte erfolgreiche Sicherung prüfen und mit einem Regressionstest absichern.
- Ein tatsächlicher Wechsel mit zwei OneDrive-Rechnern, verzögerter Übertragung, einem Anhang und einem abgelegten Dokument ist noch manuell zu prüfen. Die automatisierten Tests ersetzen keine Prüfung der realen OneDrive-Übertragung.
