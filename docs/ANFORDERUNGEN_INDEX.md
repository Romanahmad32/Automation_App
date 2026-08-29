# Anforderungen — Index

[`REQUIREMENTS.md`](../REQUIREMENTS.md) im Wurzelverzeichnis ist das **bindende**
Anforderungsdokument. Es ist versioniert und liegt in jedem Klon vor.

Diese Datei ist das **Inhaltsverzeichnis dazu, nicht der Inhalt**. Sie sagt, unter welcher Nummer
welches Thema geregelt ist — als Einstieg, und als prüfbare Gliederung: `anforderungen_test.dart`
und `DokumentationTests.cs` halten jeden `§4.8`-Verweis im Code gegen die Nummern hier.

> **Regel:** Wer fachliches Verhalten ändert, liest den Wortlaut in `REQUIREMENTS.md`. Diese
> Übersicht nennt Thema und Fundstelle, mehr nicht — sie ersetzt das Nachlesen nicht.
>
> **Nachziehen ist Pflicht, und es wird geprüft:** Wer die Gliederung in `REQUIREMENTS.md`
> ändert, zieht die Nummern hier mit nach. `anforderungen_test.dart` hält beide Gliederungen
> gegeneinander und wird rot, sobald eine Nummer nur auf einer Seite steht — sonst veralteten
> Index und Verweise gemeinsam und zeigten geschlossen auf eine Gliederung, die es nicht mehr
> gibt. Was der Test **nicht** sieht, ist der Text neben der Nummer: Eine Zeile, die unter der
> richtigen Nummer das falsche Thema nennt, bleibt grün.

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
| **[K]** Später | bewusst zurückgestellt, wird bei Bedarf ausgebaut — welche das sind, steht unter 8 |

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
| 4.7 | Versand: Mail in der App verfassen und über das Kanzlei-Postfach senden, Empfänger, Anhänge, Signatur, Textvorlagen, Versandnachweis je Vorgang; Abgrenzung siehe 8 (kein Mailprogramm) |
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
| 7.3 | Auslieferung und Aktualisierung: Setup, Datenerhalt beim Update, Update aus der App heraus (**[K]**, siehe 8) |

### 8 Nicht-Ziele / Abgrenzung

**Vor jedem Vorschlag lesen, der Funktionsumfang hinzufügt.** Die häufigste vermeidbare Fehlleistung
hier ist, einen bewusst ausgeschlossenen Bereich als „naheliegende Ergänzung" einzubauen — sie
passiert beim Bauen an einem Paragraphen, dessen Thema harmlos aussieht. Deshalb steht hier, welcher
Ausschluss auf welches Kapitel drückt: Wer an dem Kapitel arbeitet, liest die Zeile mit.

| Nicht-Ziel | drückt auf |
|---|---|
| Keine vollständige Kanzleisoftware (kein Fristenmanagement, keine Buchhaltung, keine Mandantenkommunikation über den Workflow hinaus) | §3, §5.1, §6 |
| Keine Fristen- oder Wiedervorlagelogik — die App erinnert nicht aktiv; die Übersicht nach Bearbeitungsstand genügt | §3, §4.9 |
| **Kein Mailprogramm** — die Workflow-Mails versendet die App **sehr wohl selbst** (§4.7); was fehlt, ist das Postfach: kein Posteingang zum Lesen und Beantworten, keine Ordner, keine Suche | §4.7, §4.9 |
| Keine Vollautomatisierung ohne Anwalt — Captcha, inhaltliche Freigabe, Übernahme der Antwort und Auftragsabschluss bleiben bestätigte Schritte | §4.2, §4.3, §4.5, §4.8 |
| Andere Rechtsgebiete nur getragen, nicht ausgebaut — der durchgängige Workflow ist nur für Verkehrsunfall-Mandate ausgearbeitet | §3, §4 |
| Kein Mehrbenutzer- oder Netzwerkbetrieb — Einzelplatz, ein Nutzer, lokale Daten | §2, §7 |
| Keine Auslagerung des Datenbestands — alles bleibt auf dem Rechner der Kanzlei, ohne Internet arbeitsfähig | §2, §7.2 |

### Zurückgestelltes ([K]) im Überblick

Ein **[K]** heißt: bewusst nicht gebaut. Wer es trotzdem baut, baut gegen die Anforderung — und
merkt es nicht, weil nichts rot wird. Die Übersicht steht hier, damit man das nicht erst hinterher
im Volltext findet:

| § | zurückgestellt |
|---|---|
| 4.10 | Erstkontakt über die Kanzlei-Website — **durchgehend [K]**, jeder Punkt darin |
| 7.3 | Aktualisierung aus der App heraus (Hinweis auf neue Version, Selbstaktualisierung); der Weg über ein neues Setup genügt |

Sonst trägt kein Paragraph zurückgestellte Punkte. Kommt einer dazu, gehört er in diese Tabelle —
sie ist im frischen Klon die **einzige** Auskunft darüber, und ein Ausschluss, der nur im
nicht versionierten Volltext steht, hält niemanden auf.

### 9 Offene Punkte

Bewusst noch nicht entschieden — u. a. eine offizielle Zentralruf-Schnittstelle als Alternative zur
Browser-Automatisierung, die Übernahme des Registeraltbestands, die Bezugsquelle für Updates und
der Weg des Website-Kanals. Wer auf eine dieser Fragen stößt, entscheidet sie nicht selbst.
