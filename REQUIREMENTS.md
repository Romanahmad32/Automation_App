# Anforderungen: Automatisierungs-App für eine Anwaltskanzlei

> Zweck dieses Dokuments: Es beschreibt, **was** die App erreichen soll (Anforderungen),
> nicht **wie** sie umgesetzt wird. Es dient als verbindliche Referenz für alle, die an
> diesem Projekt arbeiten — insbesondere für KI-Agenten, die den Projektkontext kennen müssen.
> Umsetzungsstand und Architektur sind hier bewusst **nicht** dokumentiert.

## 1. Vision und Geschäftsziel

Die App vereinfacht und automatisiert die alltäglichen, sich wiederholenden Routine­arbeiten
eines selbstständigen Rechtsanwalts. Sie ist als allgemeine **Vorgangs- und Aktenverwaltung**
angelegt, die den Weg eines Mandats von der Datenaufnahme bis zur fertigen, abgelegten und
versandten Korrespondenz begleitet — über alle Rechtsgebiete der Kanzlei hinweg.

Der erste **vollständig ausgebaute Anwendungsfall** ist die Regulierung von
**Verkehrsunfall-Mandaten** (Anspruchstellung gegenüber der gegnerischen
Kfz-Haftpflicht­versicherung). An diesem Fall ist der durchgängige Workflow bis zum Ende
automatisiert; andere Rechtsgebiete werden zunächst über die gemeinsame Vorgangs-,
Mandanten- und Registerverwaltung getragen und später bei Bedarf vertieft.

Erfolgskriterium: Ein Standardvorgang — von der Datenaufnahme des Mandanten bis zum
versandfertigen, korrekt abgelegten und registrierten Schreiben — soll mit minimalem
manuellem Aufwand durchführbar sein.

**Leitprinzipien:**

- **Mensch im Prozess.** Vollautomatisierung ist nicht das Ziel. Der Anwalt behält an
  definierten Stellen die Kontrolle (Captcha, inhaltliche Sichtprüfung, Freigabe vor Versand).
- **Keine Doppelerfassung.** Einmal erfasste Daten (Mandant, Referenz, Antwort der
  Versicherung, Dokument) fließen durch den gesamten Vorgang und werden nicht mehrfach
  eingetippt.
- **Minimaler Aufwand, maximale Verlässlichkeit.** Wiederkehrende Handgriffe werden
  vorbelegt oder übernommen; erfasste Daten gehen nicht verloren.

## 2. Rahmenbedingungen

- **Plattform:** Windows-Desktop-App (Einzelplatz, ein Anwalt als Nutzer, keine
  IT-Kenntnisse vorausgesetzt).
- **Ein-Klick-Betrieb:** Die App wird als **eine** gewöhnliche Windows-Anwendung per Klick
  auf das App-Symbol gestartet. Es gibt kein sichtbares Terminal; für den Nutzer verhält sie sich wie eine einzige Anwendung.
- **Dateisystemzugriff:** Die App muss auf das lokale Dateisystem zugreifen können, um
  Akten (Ordner) und Dokumente (Dateien) zu organisieren.
- **Datenhaltung:** Alle erfassten Daten (Mandanten, Vorgänge, Einstellungen, Vorlagen,
  eingegangene Antworten) werden lokal, dauerhaft und verlässlich gehalten. Sie überstehen
  einen Neustart der App und dürfen nicht durch parallele Zugriffe verloren gehen oder
  überschrieben werden (siehe 8).
- **Sprache:** Benutzeroberfläche und erzeugte Dokumente sind deutschsprachig;
  die fachliche Domäne ist deutsches Recht (RVG, Haftung dem Grunde nach, Zentralruf der Autoversicherer).
- **Mensch im Prozess:** Schritte mit rechtlicher Verantwortung (inhaltliche Prüfung,
  Versand-Freigabe) bleiben beim Anwalt.

## 3. Kernkonzept: Der Vorgang

Der **Vorgang** ist die zentrale Klammer der App und die Bezugsgröße für die Kapitel 4–8.
Ein Vorgang steht für ein einzelnes bearbeitetes Mandat/Auftrag und bündelt an einer Stelle
alle Daten, die im Laufe seiner Bearbeitung entstehen.

- **Bündelung statt Verstreuung:** Ein Vorgang verknüpft **Mandant ↔ Referenz/Aktenzeichen
  ↔ Antwort der Versicherung ↔ erstelltes Dokument ↔ Ablageort ↔ Versand**. Was in einem
  Schritt erfasst oder ermittelt wurde, steht in allen folgenden Schritten zur Verfügung,
  ohne erneut eingegeben zu werden.
- **Zuordnung über die Referenz:** Die Referenz/das Aktenzeichen identifiziert den Vorgang
  eindeutig. Über sie wird insbesondere eine eingehende Zentralruf-Antwort automatisch dem
  richtigen Vorgang zugeordnet (siehe 4.3).
- **Nachvollziehbarer Lebenszyklus:** Jeder Vorgang hat einen erkennbaren Bearbeitungsstand
  entlang seines Wegs (Anfrage gestellt → Antwort eingegangen → Schreiben erstellt →
  abgelegt → versendet/abgeschlossen). Der aktuelle Stand ist jederzeit ablesbar.
- **Übersicht und Wiederauffindbarkeit:** Offene und abgeschlossene Vorgänge sind in einer
  Übersicht auffindbar, sodass der Anwalt sieht, was noch aussteht (z. B. Vorgänge, die auf
  eine Zentralruf-Antwort warten) und was bereits erledigt ist.
- **Rechtsgebiet:** Jeder Vorgang ist einem Rechtsgebiet zugeordnet (Verkehrsrecht als
  Schwerpunkt; weitere Gebiete möglich). Das Rechtsgebiet trägt u. a. die Einordnung im
  Sachgebiete-Register (siehe 6).

## 4. Feature: Anspruchsschreiben automatisch erstellen und versenden (Verkehrsunfall)

Der voll ausgebaute Kernworkflow besteht aus einem **zweischrittigen Prozess**: zuerst
Versicherungs­ermittlung über den Zentralruf, dann — nach Eingang der Antwort — Vorlagen­­
ausfüllung, Prüfung, Ablage und Versand. Alle hier erfassten und ermittelten Daten gehören
zu **einem Vorgang** (siehe 3).

### 4.1 Schritt 1: Mandantendaten erfassen

- Der Mandant liefert die relevanten Unfalldaten, insbesondere:
  - **Unfalldatum**
  - **Kfz-Kennzeichen des Unfallgegners**
  - sowie weitere für Anfrage und Schreiben nötige Personen- und Schadensdaten.
- Die App nimmt diese Daten strukturiert entgegen.
- Handelt es sich um einen bereits bekannten Mandanten, sollen dessen Stammdaten nicht
  erneut eingegeben werden müssen, sondern aus dem Mandantenregister übernommen werden
  (siehe 5). Neue Mandanten werden bei dieser Gelegenheit erfasst.

### 4.2 Schritt 2: Zentralruf-Anfrage (Versicherungsermittlung)

- Die App füllt das Online-Anfrageformular des Zentralrufs der Autoversicherer
  (`https://www.zentralruf.de/online-anfrage/anfrageformular`) automatisch mit den
  Kanzlei- und Mandantendaten aus.
- **Captcha-Anforderung:** Ein eventuelles Captcha muss der Anwalt selbst lösen können.
  Die Automatisierung muss daher so gestaltet sein, dass der Anwalt den Vorgang sehen
  und eingreifen kann (z. B. sichtbares Browserfenster). Alternativ ist eine offizielle
  API-Schnittstelle für Anwälte zulässig, falls verfügbar.
- **Referenzformat:** Als Referenz/Aktenzeichen wird eine Zeichenkette nach folgendem
  Schema eingetragen:

  ```
  [Laufende Auftragsnummer]/[Jahr] [Abteilung]_[Kennzeichen]
  Beispiel: 84/26 C03_GG-XY 123
  ```

- **Auftragsnummern-Verwaltung:** Die App verwaltet die *laufende Auftragsnummer*
  zentral und halbautomatisch:
  - **Hinterlegen:** Die aktuelle laufende Auftragsnummer wird in den Einstellungen
    gesetzt und dort jederzeit einsehbar/korrigierbar gehalten (siehe 9).
  - **Automatisches Vorbefüllen:** Jedes „Auftragsnummer"-Feld in der App (insbesondere
    in der Referenz, aber auch in sonstigen Eingabemasken/Formularen mit diesem Feld)
    wird automatisch mit der aktuell hinterlegten Auftragsnummer vorbefüllt, sodass sie
    nicht pro Vorgang manuell eingetippt werden muss. Der Nutzer kann den vorbefüllten
    Wert bei Bedarf für den einzelnen Vorgang überschreiben.
  - **Automatisches Hochzählen:** Sobald ein Auftrag abgeschlossen ist (siehe 4.7),
    wird die hinterlegte Auftragsnummer um eins erhöht. Das Hochzählen erfolgt entweder
    automatisch oder erst nach Rückfrage/Bestätigung durch den Nutzer (halbautomatische
    Vergabe); welche der beiden Varianten gilt, ist konfigurierbar bzw. dem Nutzer wird
    die Erhöhung zur Bestätigung vorgeschlagen.
- **Kanzleidaten:** Die Daten des Anfragers (Kanzlei/Anwalt) sind einmalig in den
  Einstellungen hinterlegbar und werden nicht pro Vorgang neu eingetippt.

### 4.3 Schritt 3: Zentralruf-Antwort verarbeiten

- Der Zentralruf antwortet per E-Mail. Diese Antwort enthält die für das Anspruchsschreiben
  relevanten Daten, vor allem die **Daten der gegnerischen Versicherung**
  (Versicherer, Versicherungsschein-/Schadennummer usw.).
- Die App muss diese Informationen aus der Antwort **extrahieren, dem richtigen Vorgang
  zuordnen (über die Referenz) und speichern**, sodass sie für die Vorlagen­ausfüllung
  zur Verfügung stehen.
- **Weg der E-Mail in die App:** Es gibt zwei sich ergänzende Wege:
  - **Automatische Postfach-Überwachung (Hauptweg):** Die App überwacht das Postfach des
    Anwalts und erfasst eingehende Zentralruf-Antworten selbsttätig (Erkennung über den
    Betreff). Das geschieht ereignisbasiert — die App wird vom Postfach benachrichtigt,
    sobald eine passende Mail eintrifft, und pollt nicht in starrem Takt. Voraussetzung ist
    ein einmalig in den Einstellungen hinterlegter Postfach-Zugang (für Gmail ein
    App-Passwort bei aktivierter 2-Faktor-Authentifizierung). Ist kein Zugang hinterlegt,
    bleibt die Überwachung inaktiv.
  - **Manuelles Einfügen/Hochladen (anbieterunabhängiger Rückfall):** Der Anwalt kann den
    Mailtext einfügen oder die Nachricht als `.eml`/`.txt` hochladen; das funktioniert mit
    jedem Mail-Anbieter und ohne hinterlegten Zugang.
  - Beide Wege münden in dieselbe Auswertung und liefern dieselben Hinweise auf mögliche
    Falschzuordnungen. Das Requirement bleibt: Die Daten der Antwort müssen ohne
    fehler­trächtiges Abtippen in den Vorgang übernommen werden können.
- **Übernahme bleibt bestätigter Schritt:** Eingegangene Antworten werden dem passenden
  Vorgang vorgeschlagen; die endgültige Übernahme in den Vorgang bestätigt der Anwalt.

### 4.4 Schritt 4: Vorlage ausfüllen

Es existieren zwei Arten von Word-Vorlagen; der Nutzer wählt pro Vorgang aus, welche Art
verwendet wird ("Auflistung vorhanden: ja/nein"):

1. **Vorlage mit Auflistung:** Enthält eine Tabelle (Schadensaufstellung), die automatisch
   befüllt wird. Die **RVG-Anwaltskosten­kalkulation** (Geschäftsgebühr nach Gegenstandswert
   gemäß § 13 RVG, aktueller Gebührenstand) wird im Dokument automatisiert berechnet und eingetragen.
2. **Vorlage ohne Auflistung:** Enthält stattdessen eine **HGN-Sektion**
   (Haftung dem Grunde nach).

Gemeinsame Anforderungen:

- Platzhalter in der Vorlage werden mit den erfassten Mandanten-, Unfall- und
  Versicherungsdaten befüllt.
- Es dürfen keine unbefüllten Platzhalter im fertigen Dokument verbleiben, ohne dass
  der Nutzer darauf hingewiesen wird.
- Welche Vorlagen zur Auswahl stehen und welche Felder sie besitzen, bestimmt der Anwalt
  über die Vorlagenverwaltung (siehe 7).

### 4.5 Schritt 5: Prüfung und Korrektur

- **Sichtprüfung:** Der Anwalt prüft das ausgefüllte Dokument vor Versand selbst
  (Vorschau in der App). Eine Freigabe durch den Anwalt ist Voraussetzung für den Versand.
- **Korrekturmöglichkeit:** Muss das Dokument überarbeitet werden, soll es entweder
  direkt in der App änderbar sein **oder** in einem externen Editor (z. B. MS Word)
  geöffnet werden können, in dem das Dokument bereits geladen ist.

### 4.6 Schritt 6: Ablage im Aktensystem

- Vor dem Speichern prüft die App, ob für den Mandanten bereits eine **Akte**
  (Ordner im Dateisystem) existiert. **Match-Kriterium: Mandantenname.**
  - Akte vorhanden → ein neuer Unterordner wird in der bestehenden Akte angelegt.
  - Akte nicht vorhanden (Neumandant) → eine neue Akte wird angelegt, darin der Unterordner.
- Das ausgefüllte Dokument wird im Unterordner gespeichert.
- **Unterordner-Namensschema:**

  ```
  [Stichwort]v[Datum] [Notiz]
  ```

  *Offen:* Das Stichwort ist meistens der Name des Kunden; die endgültige Konvention
  steht noch nicht fest.
- Der Ablageort wird am Vorgang festgehalten, damit das Dokument später wiederauffindbar ist.

### 4.7 Schritt 7: Auftragsabschluss und E-Mail-Versand

- **E-Mail-Versand:** Das freigegebene Dokument wird per E-Mail versendet.
  - **Empfänger:** Standardmäßig sowohl die gegnerische Versicherung als auch der Mandant.
    Die Empfängerlogik muss **konfigurierbar** sein (z. B. in den Einstellungen: nur
    Versicherung, nur Mandant, beide).
- **Abschluss:** Mit dem Abschluss des Auftrags
  - gilt der Vorgang als erledigt (Status „versendet/abgeschlossen"),
  - wird die laufende Auftragsnummer weitergezählt (siehe 4.2),
  - und der Vorgang wird in das Sachgebiete-/Auftragsregister aufgenommen (siehe 6).
- Ziel ist, dass Versand und Abschluss zu einem zusammenhängenden Schritt gehören, damit
  die Auftragsnummer erst dann weiterzählt, wenn der Auftrag tatsächlich hinausgegangen ist.

## 5. Mandantenregister (Stammdaten)

- Die App führt ein **Register der Mandanten** mit ihren Stammdaten (Name/Anrede, Anschrift,
  Kontaktdaten, Notizen).
- Wiederkehrende Mandanten werden **einmal erfasst und wiederverwendet**: Bei einem neuen
  Vorgang für einen bekannten Mandanten werden dessen Daten übernommen, statt sie erneut
  einzugeben.
- Einem Mandanten können mehrere **Kfz-Kennzeichen** und mehrere **Akten** zugeordnet sein.
- Das Register bildet die Grundlage für die Akten-Ablage (Match über den Mandantennamen,
  siehe 4.6) und für die Parteienbezeichnung „Mandant ./. Gegner" im Sachgebiete-Register
  (siehe 6).

## 6. Sachgebiete-/Auftragsregister

Die Kanzlei führt ein fortlaufendes, mehrseitiges **Auftrags-/Sachgebiete-Register** (in
Form einer Word-Tabelle) über alle bearbeiteten Aufträge. Ziel der App ist, dieses Register
ohne manuelles Nachtragen aktuell zu halten.

- **Automatische Aufnahme:** Wird ein Vorgang abgeschlossen (siehe 4.7), erscheint er als
  neue Zeile im Register.
- **Spaltenschema je Zeile:**
  - laufende Nummer
  - Aktenzeichen + Abteilung
  - „Name ./. Gegner" samt Sachbestand/Datum
  - Rechtsgebiet
- **In-App-Ansicht:** Die Registerdaten sind in der App im exakten Spaltenschema einsehbar.
- **Ausgabe ins Kanzlei-Registerdokument:** Ziel ist, die abgeschlossenen Vorgänge in das
  reale, mehrseitige Registerdokument der Kanzlei zu schreiben. Das endgültige Format/die
  Vorlage dieses Dokuments ist noch festzulegen (siehe 11).

## 7. Vorlagenverwaltung

- Der Anwalt kann seine **Word-Vorlagen selbst verwalten**, ohne dass ein Entwickler
  eingreifen muss.
- Zu einer Vorlage gehören insbesondere: ein Name, die zugehörigen Word-Dateien (Variante
  mit und ohne Schadensaufstellung, siehe 4.4) sowie die Beschreibung der Felder, die beim
  Ausfüllen abgefragt und in die Vorlage eingesetzt werden.
- Neue Vorlagen können angelegt, bestehende geändert und entfernt werden. Die in einem
  Vorgang zur Auswahl stehenden Vorlagen ergeben sich aus dieser Verwaltung.

## 8. Datensicherung & Datenintegrität

- **Schutz vor Datenverlust:** Erfasste Daten dürfen weder durch einen App-Neustart noch
  durch parallele Zugriffe verloren gehen oder inkonsistent werden.
- **Sichern und Wiederherstellen:** Der Anwalt muss seine Daten **sichern** und aus einer
  Sicherung **wiederherstellen** können — ohne IT-Kenntnisse, aus der App heraus.
- Eine ungültige oder beschädigte Sicherung darf den vorhandenen Datenbestand nicht
  zerstören; der Nutzer wird auf das Problem hingewiesen.

## 9. Einstellungen (Querschnittsanforderung)

In den App-Einstellungen müssen mindestens konfigurierbar sein:

- Kanzlei-/Anfragerdaten für die Zentralruf-Anfrage (Name, Anschrift, Kontaktdaten usw.).
- Postfach-Zugang für die automatische Überwachung der Zentralruf-Antworten (siehe 4.3):
  Postfach-Adresse und Zugangsdaten (für Gmail ein App-Passwort) sowie der Betreff-Filter;
  ohne hinterlegten Zugang bleibt die Überwachung inaktiv.
- Empfängerlogik des E-Mail-Versands (siehe 4.7).
- Stammordner des Aktensystems im Dateisystem (siehe 4.6).
- Abteilungskürzel und laufende (aktuelle) Auftragsnummer für das Referenzformat;
  diese Auftragsnummer wird automatisch in „Auftragsnummer"-Felder vorbefüllt und
  nach Auftragsabschluss hochgezählt (siehe 4.2). Ob das Hochzählen automatisch oder
  erst nach Bestätigung erfolgt, ist hier ebenfalls einstellbar.
- Darstellungsoptionen für die erzeugten Dokumente (z. B. Farbe der Tabellen-Titelzeile
  der Schadensaufstellung passend zum Kanzlei-Vorbild).
- Zugang zur Datensicherung (siehe 8).

## 10. Nicht-Ziele / Abgrenzung

- **Keine vollständige Kanzleisoftware:** Kein Fristenmanagement, keine Buchhaltung,
  keine Mandantenkommunikation über den beschriebenen Workflow hinaus.
- **Keine Vollautomatisierung ohne Anwalt:** Captcha-Lösung, inhaltliche Freigabe und die
  Übernahme der Zentralruf-Antwort bleiben bewusst bestätigte, manuelle Schritte.
- **Andere Rechtsgebiete zunächst nur getragen, nicht ausgebaut:** Über die gemeinsame
  Vorgangs-, Mandanten- und Registerverwaltung hinaus ist der durchgängig automatisierte
  Workflow (Zentralruf, RVG, Anspruchsschreiben) zunächst nur für Verkehrsunfall-Mandate
  ausgearbeitet. Weitere Rechtsgebiete werden erweitert, wenn dies beschlossen wird.

## 11. Offene Punkte (bewusst noch nicht entschieden)

| Thema | Stand |
|---|---|
| Endgültige Konvention für das [Stichwort] im Unterordnernamen | Offen (meist Mandantenname) |
| Offizielle Zentralruf-API für Anwälte als Alternative zur Browser-Automatisierung | Zu prüfen |
| Format/Vorlage des realen Sachgebiete-Registerdokuments (Ausgabe aus 6) | Offen — solange nicht festgelegt, existiert nur die In-App-Ansicht |
| Kopplung des Auftragsnummer-Hochzählens an tatsächlichen Versand vs. reinen Abschluss | Zu klären, sobald der E-Mail-Versand (4.7) umgesetzt ist |
| Tiefergehender Ausbau weiterer Rechtsgebiete über die gemeinsame Verwaltung hinaus | Offen — wird erweitert, wenn beschlossen |
