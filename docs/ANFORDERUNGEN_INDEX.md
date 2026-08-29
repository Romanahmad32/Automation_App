# Anforderungen — Index

`REQUIREMENTS.md` im Wurzelverzeichnis ist das **bindende** Anforderungsdokument. Es ist
absichtlich **nicht versioniert** (`.gitignore`): es enthält Kanzlei-Interna, das Repo ist
öffentlich. Im frischen Klon, im Worktree und in einer Cloud-Sitzung fehlt es deshalb.

Diese Datei ist der **Ersatz für das Inhaltsverzeichnis, nicht für den Inhalt**. Sie sagt, unter
welcher Nummer welches Thema geregelt ist — damit man gezielt danach fragen kann, statt die
Anforderung zu raten.

> **Regel:** Wer fachliches Verhalten ändert und `REQUIREMENTS.md` nicht vorliegen hat,
> **fragt nach**. Diese Übersicht ist keine Ermächtigung, den Wortlaut zu erfinden — sie nennt
> Thema und Fundstelle, mehr nicht.

## Wie die Anforderungen mit dem Code verbunden sind

Jeder Feature-Steckbrief `Automation_App_Frontend/lib/features/<feature>/FEATURE.md` nennt in
seinem Feld `Anforderung:` die zuständigen Paragraphen. Die Zuordnung steht damit **nur dort** —
in eine Richtung, damit sie nicht an zwei Stellen auseinanderläuft:

```
# Welches Feature setzt §6.2 um?
grep -l "6.2" Automation_App_Frontend/lib/features/*/FEATURE.md
```

## Prioritätsmarken

Jede einzelne Anforderung im Dokument trägt eine Marke:

| Marke | Bedeutung |
|---|---|
| **[M]** Muss | ohne sie verfehlt die App ihren Zweck |
| **[S]** Soll | deutlicher Nutzen, der Kernworkflow läuft aber auch ohne |
| **[K]** Später | bewusst zurückgestellt, wird bei Bedarf ausgebaut |

Was tatsächlich gebaut ist, steht **nicht** dort, sondern in [`docs/STAND.md`](STAND.md).

## Gliederung

### 1 Zweck und Erfolgskriterien

| § | Thema |
|---|---|
| 1.1 | Was die App erreichen soll — die Kette von der Datenaufnahme bis zum abgelegten Schreiben |
| 1.2 | Woran sich der Erfolg messen lässt (u. a. keine Doppelerfassung, drei bewusste Eingriffe) |
| 1.3 | Leitprinzipien: Mensch im Prozess, keine Doppelerfassung, vorschlagen statt entscheiden, Verlässlichkeit vor Funktionsumfang |

### 2 Rahmenbedingungen

Plattform, Ein-Klick-Betrieb, Dateisystemzugriff, Datenhaltung, Sprache und Rechtsdomäne.
Ohne Unterabschnitte — bei Fragen zu Betriebsform oder Datenhaltung hierher.

### 3 Der Vorgang als zentrale Klammer

Der Vorgang bündelt Mandant, Referenz, Antwort, Dokumente, Ablageort und Versand; Zuordnung über
die Referenz, ablesbarer Lebenszyklus, mehrere Schreiben je Vorgang, Rechtsgebiet, Übersicht als
Startpunkt, Wiederauffindbarkeit. Bezugsgröße für die Kapitel 4–7.

### 4 Kernworkflow: Anspruchsschreiben Verkehrsunfall

| § | Thema |
|---|---|
| 4.1 | Mandantendaten erfassen; Stammdaten bekannter Mandanten übernehmen |
| 4.2 | Zentralruf-Anfrage: Formular vorbefüllen, Captcha bleibt beim Anwalt, Aufbau der Referenz |
| 4.3 | Zentralruf-Antwort verarbeiten: Auslesen, Zuordnen, manueller Weg und Postfach-Überwachung, bestätigte Übernahme, Negativ-Antwort |
| 4.4 | Vorlage ausfüllen: zwei Vorlagenarten, RVG-Kostenkalkulation, keine unbefüllten Platzhalter |
| 4.5 | Prüfung und Korrektur: Sichtprüfung in der Vorschau, Freigabe, Korrekturweg |
| 4.6 | Ablage in der Akte; Ablageort am Vorgang festhalten |
| 4.7 | Versand: Mail in der App verfassen und über das Kanzlei-Postfach senden, Empfänger, Anhänge, Signatur, Textvorlagen, Versandnachweis je Vorgang |
| 4.8 | Auftragsabschluss als eigener Schritt: erledigt, Auftragsnummer weiterzählen, Registereintrag |
| 4.9 | Folgekorrespondenz zu einem offenen Vorgang |
| 4.10 | Erstkontakt über die Kanzlei-Website (durchgehend **[K]**) |

### 5 Stammdaten und Wissen

| § | Thema |
|---|---|
| 5.1 | Mandantenregister: Stammdaten, Wiederverwendung, mehrere Kennzeichen/Akten, Duplikatschutz |
| 5.2 | Versicherer-Wissensbasis aus Zentralruf-Antworten; Lücken aus früherem Wissen füllen |
| 5.3 | Vorlagenverwaltung durch den Anwalt selbst: Word-Vorlagen, Felder, Mail-Textvorlagen |

### 6 Ablage und Register

| § | Thema |
|---|---|
| 6.1 | Aktenablage im Dateisystem: Akte je Mandant, Namensmuster der Unterordner, Stammordner |
| 6.2 | Sachgebiete-/Auftragsregister: die App führt es, automatische Aufnahme, Spaltenschema, Ansicht und Export |

### 7 Betrieb

| § | Thema |
|---|---|
| 7.1 | Einstellungen: Kanzleidaten, Abteilung und laufende Auftragsnummer (hinterlegen/vorbefüllen/hochzählen), Aktenstammordner, Versand, Postfach-Zugang, Darstellung, Sicherung |
| 7.2 | Datensicherung und Datenintegrität: Schutz vor Datenverlust, Sichern/Wiederherstellen, robuste Wiederherstellung, dauerhafte Kennungen, Änderungsstand |
| 7.3 | Auslieferung und Aktualisierung: Setup, Datenerhalt beim Update, Update aus der App heraus |

### 8 Nicht-Ziele / Abgrenzung

Was die App **nicht** wird: keine vollständige Kanzleisoftware, keine Fristenlogik, kein
eigenständiger Mailversand, keine Vollautomatisierung ohne Anwalt, andere Rechtsgebiete zunächst
nur getragen, kein Mehrbenutzerbetrieb, keine Auslagerung des Datenbestands.

**Vor jedem Vorschlag lesen, der Funktionsumfang hinzufügt.** Die häufigste vermeidbare Fehlleistung
hier ist, einen bewusst ausgeschlossenen Bereich als „naheliegende Ergänzung" einzubauen.

### 9 Offene Punkte

Bewusst noch nicht entschieden — u. a. eine offizielle Zentralruf-Schnittstelle als Alternative zur
Browser-Automatisierung, die Übernahme des Registeraltbestands, die Bezugsquelle für Updates und
der Weg des Website-Kanals. Wer auf eine dieser Fragen stößt, entscheidet sie nicht selbst.
