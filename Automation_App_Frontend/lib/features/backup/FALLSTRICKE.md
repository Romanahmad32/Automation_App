# backup — Fallstricke

## Ablage ist keine Cloud-Bestätigung

Die App nutzt den lokal synchronisierten Ordner, keine OneDrive-API. Ein erfolgreiches Schreiben
belegt weder den Upload noch den Download auf einem anderen Rechner. Die Oberfläche unterscheidet
lokale Änderungen, Bereitstellung, wartende Datei, verfügbares Angebot und bestätigte Übernahme.
`SynchronisationsLeiste` bleibt als Statusquelle in der Shell und prüft alle 15 Sekunden und beim Wiederaufnehmen; parallele Abfragen werden
vermieden. Ein Dateiplatzhalter kann die erwartete Größe haben. Erst beim Übernehmen wird der
Inhalt geladen und mit SHA-256 geprüft. Der Status verspricht deshalb vorher keine geprüfte Datei.

## Inhalt und Herkunft statt neuer Sicherungszeit

`SynchronisationsVerlauf` speichert die tatsächlich bereitgestellte oder übernommene Basis neben
der lokalen Datenbank. Sie wird niemals aus einer vom Cloud-Client überschriebenen eigenen
Arbeitsplatz-Datei abgeleitet. `BestandsFingerabdruck` prüft SQL-Inhalte, Vorlagen und Anhänge;
Dateimetadaten dienen nur als Cache. WAL-Checkpoints und bloßes Öffnen machen keinen neuen Stand.

Jede inhaltliche Änderung erhält eine Revision und kennt die Vorgänger. Ein Nachfolger wird auch
bei abweichender Rechneruhr erkannt. Zwei unabhängige Zweige oder lokale Änderungen gegenüber der
Basis ergeben einen Konflikt. Bei alten Akten ohne Revision bleibt der Zeitvergleich als
Kompatibilitätsweg bestehen; beide Rechner sollten deshalb dieselbe neue App-Version verwenden.
Archive desselben Rechners aus derselben Sekunde erhalten unterschiedliche Namen.

## Eine Bestätigung gilt genau einmal für den angezeigten Vergleich

`pruefkennung` bindet Dateiname, Revision, Prüfsumme und lokalen Fingerabdruck. Ändert sich zwischen
Anzeige und Klick ein Stand, wird die Übernahme zurückgewiesen. `konfliktBestaetigt` ist getrennt:
Eine normale Übernahmefreigabe ist keine Freigabe, inzwischen entstandene lokale Änderungen zu
verwerfen. Das Backend prüft den lokalen Inhalt nochmals unter der Schreibsperre beim Import.

## Vorbereiten, prüfen, dann tauschen

Neue ZIPs enthalten `automation.db`, `Vorlagen/`, erfasste `Anhaenge/` und
das Prüfsummenmanifest. Passwörter, Postfachkonfiguration und OAuth-Tokens bleiben lokal.
Dateien werden beim Packen gleichzeitig gehasht; ein kompletter ZIP-Inhalt wird nicht im Speicher
gehalten. Ungültige Pfade, doppelte Einträge, übergroße Archive und falsche Prüfsummen werden vor
dem Tausch abgewiesen. Die Datenbank durchläuft `integrity_check`; unbekannte neuere Migrationen
verlangen ein App-Update. Alte `.db`-/ZIP-Dateien sind weiterhin einspielbar.

Migration und Pfadanpassung laufen an einer isolierten Kopie. SQLite Online Backup ersetzt die
aktive Datenbank transaktional; vorhandene WAL-/SHM-Dateien werden nicht von Hand gelöscht.
`ImportDateien` kann vorbereitete Dateiänderungen bei abgefangenen Fehlern zurücknehmen. Der
bisherige Bestand wird vorab vollständig gesichert. Ein harter Prozess- oder Rechnerausfall ist
keine gemeinsame Transaktion über alle Dateien; die Vor-Import-Sicherung bleibt der Rückweg.

Eine fehlende HTTP-Antwort kann auch nach erfolgreicher Übernahme auftreten. Deshalb darf die
Oberfläche bei einer unbekannten Fehlerursache nicht behaupten, es habe sich nichts geändert.

## Keine alten Ansichten nach einem Import

Der Start-Gate steht vor Router und Theme. Im laufenden Betrieb blockiert eine Importanzeige die
Bedienung; `DatenstandSignal` baut nach Erfolg Router, Theme und Formulare neu auf. Die Meldung des
Imports bleibt sichtbar, insbesondere Hinweise auf übersprungene Vorlagen. Ungespeicherte Eingaben
werden verworfen; die Bestätigung nennt das ausdrücklich.

`DatenbankWechsel` weist Speicherversuche alter EF-Kontexte ab. `DatenstandMiddleware` und
`DatenstandInterceptor` ergänzen die Prüfung für neue HTTP-Aufträge alter Ansichten. Ein neuer
Datenstand in einer späteren Antwort löst ebenfalls das Neuladen aus. Beide Schutzwege gelten
zusätzlich zur Prüfung der konkreten Übernahme, nicht als Ersatz dafür.

## Portable Dateien und Einstellungspfade

Erfasste Mailanhänge werden im ZIP mit relativen Pfaden gespeichert und beim Import in den
Anhangordner des Zielrechners kopiert. Fehlende erfasste Anhänge verhindern eine unvollständige
neue Sicherung. Ältere Sicherungen enthielten sie nicht und können sie nicht nachträglich liefern.

`AktenPfadSicherung` verankert Akten-/Dokumentverweise im eingestellten Aktenstamm. Die eigentlichen
Akten werden separat synchronisiert. Fremde absolute Einstellungspfade bleiben beim lokalen Wert,
OneDrive-Anker werden übernommen. Fehlt das benötigte Konto oder ein Aktenstamm für portable
Aktenverweise, muss die Einrichtung vervollständigt werden. Abweichende lokale Word-Vorlagen
werden weiterhin erhalten und in der Importmeldung genannt.

## Zeitgeber, Aufbewahrung und Fehler

Zeitgeber, manueller Bereitstellen-Knopf, Vorgangsabschluss und Beenden verwenden dieselbe
Sicherung. Eine gemeinsame Schleuse serialisiert sie mit der Arbeitsplatzübernahme. Der
30-Minuten-Zeitgeber prüft einschließlich reiner Vorlagen-/Anhangänderungen. Die Tag/Woche/Monat-
Staffel verwendet den Zeitpunkt im Dateinamen, räumt nur eigene Archive auf und erhält das
neueste Archiv. Unveränderte Inhalte werden nicht neu komprimiert und hochgeladen.

Die letzte automatische Sicherung wird lokal gemerkt, weil beim Beenden kein Fenster mehr offen
ist. Fehler werden beim nächsten Start und unter Einstellungen → Datensicherung sichtbar; Quittieren löscht den
Zeitpunkt nicht. Export/Import verwenden fünf Minuten HTTP-Zeitlimit und das Multipart-Feld
`datei`. Größere Übertragungen bleiben beim OneDrive-Client; die App zeigt dafür keine erfundene
Prozentanzeige.

Die Bedienung liegt unter Einstellungen → Datensicherung.
SynchronisationsBereich reicht den zentralen Zustand an diese Ansicht durch; es gibt keinen zweiten Zeitgeber.
Importmeldungen bleiben unabhängig vom geöffneten Reiter in der Shell sichtbar.
