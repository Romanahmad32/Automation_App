# Anforderungen: Automatisierungs-App für eine Anwaltskanzlei

> **Zweck dieses Dokuments:** Es beschreibt, **was** die App erreichen soll, nicht **wie** sie
> umgesetzt wird. Es ist die verbindliche Referenz für alle, die an diesem Projekt arbeiten —
> insbesondere für KI-Agenten, die den Projektkontext brauchen. Umsetzungsstand und Architektur
> stehen bewusst **nicht** hier, sondern in `CLAUDE.md`.
>
> **Priorisierung:** Jede Anforderung trägt einen Marker.
> **[M] Muss** — ohne sie verfehlt die App ihren Zweck.
> **[S] Soll** — deutlicher Nutzen, der Kernworkflow läuft aber auch ohne.
> **[K] Später** — bewusst zurückgestellt, wird bei Bedarf ausgebaut.

## 1. Zweck und Erfolgskriterien

### 1.1 Was die App erreichen soll

Ein selbstständiger Rechtsanwalt bearbeitet dieselben Routinehandgriffe für jedes Mandat immer
wieder: Mandantendaten aufnehmen, die gegnerische Versicherung ermitteln, ein Schreiben aus einer
Word-Vorlage bauen, Anwaltskosten berechnen, das Ergebnis ablegen, versenden und ins Register
eintragen. Jeder dieser Schritte erzeugt Daten, die der nächste Schritt erneut braucht — heute
werden sie mehrfach abgetippt, und genau dabei entstehen Fehler und Zeitverlust.

**Die App schließt diese Kette.** Sie führt einen Mandatsauftrag von der Datenaufnahme bis zum
versandfertigen, abgelegten und registrierten Schreiben, ohne dass eine einmal erfasste Angabe
ein zweites Mal eingegeben werden muss. Der Anwalt entscheidet weiterhin alles Inhaltliche; die
App übernimmt das Zusammentragen, Ausfüllen, Rechnen, Ablegen und Nachhalten.

Sie ist als allgemeine **Vorgangs- und Aktenverwaltung** über alle Rechtsgebiete der Kanzlei
angelegt. Der erste vollständig ausgebaute Anwendungsfall ist die Regulierung von
**Verkehrsunfall-Mandaten** (Anspruchstellung gegenüber der gegnerischen
Kfz-Haftpflichtversicherung); weitere Rechtsgebiete werden zunächst über die gemeinsame Vorgangs-,
Mandanten- und Registerverwaltung getragen (siehe 8).

### 1.2 Woran sich der Erfolg messen lässt

Ein Standardvorgang gilt als erfolgreich unterstützt, wenn:

1. **Keine Angabe wird zweimal eingetippt.** Was in einem Schritt erfasst oder aus einer Antwort
   ermittelt wurde, steht in jedem folgenden Schritt vorbelegt bereit.
2. **Nur drei bewusste Eingriffe sind nötig:** Captcha lösen, Dokument freigeben, Mail absenden.
   Alles andere geschieht auf Knopfdruck oder von selbst.
3. **Nach dem Abschluss stimmt alles ohne Nacharbeit:** Dokument liegt in der richtigen Akte, der
   Vorgang steht im Register, die laufende Auftragsnummer ist weitergezählt.
4. **Nichts geht verloren und nichts bleibt liegen:** Der Anwalt sieht jederzeit, welche Vorgänge
   auf etwas warten und welche fertig sind.

### 1.3 Leitprinzipien

- **Mensch im Prozess.** Vollautomatisierung ist ausdrücklich nicht das Ziel. An definierten
  Stellen behält der Anwalt die Kontrolle: Captcha, inhaltliche Sichtprüfung, Übernahme der
  Zentralruf-Antwort, Freigabe vor Versand.
- **Keine Doppelerfassung.** Siehe 1.2 (1). Dieses Prinzip hat im Zweifel Vorrang vor Bequemlichkeit
  an anderer Stelle.
- **Vorschlagen statt entscheiden.** Wo die App Daten zuordnet oder vorbelegt, macht sie das
  erkennbar und korrigierbar — sie überschreibt nichts stillschweigend.
- **Verlässlichkeit vor Funktionsumfang.** Erfasste Daten gehen nicht verloren; lieber eine
  Funktion weniger als ein unsicherer Datenbestand.

## 2. Rahmenbedingungen

- **[M] Plattform:** Windows-Desktop-App, Einzelplatz, ein Anwalt als Nutzer, keine IT-Kenntnisse
  vorausgesetzt.
- **[M] Ein-Klick-Betrieb:** Die App startet per Klick auf das App-Symbol wie jede gewöhnliche
  Windows-Anwendung. Kein sichtbares Terminal, kein separater Serverstart — für den Nutzer ist es
  eine einzige Anwendung.
- **[M] Dateisystemzugriff:** Die App organisiert Akten (Ordner) und Dokumente (Dateien) im lokalen
  Dateisystem.
- **[M] Datenhaltung:** Alle erfassten Daten (Mandanten, Vorgänge, Einstellungen, Vorlagen,
  eingegangene Antworten) werden lokal, dauerhaft und verlässlich gehalten. Sie überstehen einen
  Neustart der App und dürfen durch parallele Zugriffe weder verloren gehen noch inkonsistent
  werden (siehe 7.2).
- **[M] Sprache und Domäne:** Oberfläche und erzeugte Dokumente sind deutschsprachig; die fachliche
  Domäne ist deutsches Recht (RVG, Haftung dem Grunde nach, Zentralruf der Autoversicherer).

## 3. Der Vorgang als zentrale Klammer

Der **Vorgang** ist die zentrale Einheit der App und die Bezugsgröße für die Kapitel 4–7. Ein
Vorgang steht für einen bearbeiteten Mandatsauftrag und bündelt an einer Stelle alle Daten, die im
Lauf seiner Bearbeitung entstehen.

- **[M] Bündelung statt Verstreuung:** Ein Vorgang verknüpft **Mandant ↔ Zeichen ↔ Antwort der
  Versicherung ↔ erstellte Dokumente ↔ Ablageort ↔ Versand**. Was in einem Schritt erfasst
  wurde, steht in allen folgenden zur Verfügung.
- **[M] Zuordnung über die Referenz:** Die Referenz identifiziert den Vorgang eindeutig. Über
  sie wird eine eingehende Zentralruf-Antwort dem richtigen Vorgang zugeordnet (siehe 4.3).
- **[M] Nachvollziehbarer Lebenszyklus:** Jeder Vorgang hat einen ablesbaren Bearbeitungsstand:
  *Anfrage gestellt → Antwort eingegangen → Schreiben erstellt → abgelegt → abgeschlossen.*
- **[M] Mehrere Schreiben je Vorgang:** Ein Vorgang bleibt nach dem ersten Anspruchsschreiben offen
  und kann weitere Schreiben tragen (siehe 4.9). Zeichen, Akte und Auftragsnummer bleiben dabei
  dieselben.
- **[M] Rechtsgebiet:** Jeder Vorgang ist einem Rechtsgebiet zugeordnet (Verkehrsrecht als
  Schwerpunkt). Das Rechtsgebiet trägt die Einordnung im Sachgebiete-Register (siehe 6.2).
- **[S] Übersicht als Startpunkt:** Beim Start zeigt die App die Vorgänge **nach Bearbeitungsstand
  gruppiert** — was auf eine Antwort wartet, wofür ein Schreiben fällig ist, was fertig, aber noch
  nicht abgeschlossen ist. Von dort führt ein Klick direkt in den nächsten Arbeitsschritt.
- **[S] Wiederauffindbarkeit:** Vorgänge sind über Mandant, Kennzeichen, Zeichen und Versicherer
  auffindbar — auch abgeschlossene.

## 4. Kernworkflow: Anspruchsschreiben Verkehrsunfall

Der Workflow besteht aus zwei Phasen: zuerst die Versicherungsermittlung über den Zentralruf, dann
— nach Eingang der Antwort — Vorlagenausfüllung, Prüfung, Ablage, Versand und Abschluss. Alle
dabei erfassten Daten gehören zu **einem Vorgang** (siehe 3).

### 4.1 Mandantendaten erfassen

- **[M]** Die App nimmt die Unfalldaten strukturiert entgegen, insbesondere **Unfalldatum** und
  **Kfz-Kennzeichen des Unfallgegners**, dazu die für Anfrage und Schreiben nötigen Personen- und
  Schadensdaten.
- **[M] Jedes Kennzeichen nennt seinen Halter.** An einem Unfall sind zwei Fahrzeuge beteiligt;
  „Kennzeichen" allein sagt nicht, welches gemeint ist. Der angebotene und dokumentierte Name ist
  deshalb **Gegnerkennzeichen** für das Fahrzeug des Unfallgegners und **Mandantenkennzeichen** für
  das des Geschädigten — in der Oberfläche, in den Datenquellen der Vorlagenfelder und in den
  Platzhaltern der Word-Dateien. Vorlagen, die noch das blosse `{{Kennzeichen}}` tragen, werden
  weiterhin als Gegnerkennzeichen gefüllt: Das Umbenennen darf keine bestehende Word-Datei brechen.
- **[M]** Bei einem bereits bekannten Mandanten werden dessen Stammdaten aus dem Mandantenregister
  übernommen statt erneut eingegeben (siehe 5.1). Neue Mandanten werden bei dieser Gelegenheit
  erfasst.

### 4.2 Zentralruf-Anfrage (Versicherungsermittlung)

- **[M]** Die App füllt das Online-Anfrageformular des Zentralrufs der Autoversicherer
  (`https://www.zentralruf.de/online-anfrage/anfrageformular`) mit den Kanzlei- und Mandantendaten
  aus.
- **[M] Captcha-Anforderung:** Ein eventuelles Captcha muss der Anwalt selbst lösen können. Die
  Automatisierung muss daher sichtbar und eingreifbar sein (sichtbares Browserfenster). Eine
  offizielle API-Schnittstelle für Anwälte wäre zulässig, falls verfügbar (siehe 9).
- **[M] Referenzformat:** Als Referenz wird eingetragen:

  ```
  [Laufende Auftragsnummer]/[Jahr] [Abteilung]_[Kennzeichen]
  Beispiel: 84/26 C03_HG-E 1427
  ```

  Kfz-Kennzeichen werden durchgängig mit Bindestrich geschrieben (`HG-E 1427`).
- **[M] Zeichen und Referenz sind zweierlei.** Der vordere Teil ohne Kennzeichen — `84/26 C03` —
  heißt **Zeichen**. Er ist der Bezeichner der Kanzlei und steht in den Briefen, im Register, im
  Mailbetreff, im Dateinamen und überall in der Oberfläche. Die volle **Referenz** mit angehängtem
  Kennzeichen trägt allein die maschinelle Zuordnung der Zentralruf-Antwort (siehe 4.3) und
  erscheint nur, wo sie genau diese Aufgabe erfüllt: im Zentralruf-Formular, beim Zuordnen einer
  Antwort und als Nebenzeile am Vorgang. Der Begriff heißt **Zeichen** — nicht Aktenzeichen, nicht
  Referenz; zwei Wörter für dieselbe Sache wären eines zu viel.
- **[M]** Die laufende Auftragsnummer und die Kanzleidaten kommen aus den Einstellungen und werden
  nicht pro Vorgang eingetippt (siehe 7.1).

### 4.3 Zentralruf-Antwort verarbeiten

Der Zentralruf antwortet per E-Mail mit den Daten der gegnerischen Versicherung (Versicherer,
Versicherungsschein-/Schadennummer, Kontaktdaten).

- **[M] Extrahieren statt Abtippen:** Die App liest diese Daten aus der Antwort aus, ordnet sie über
  die Referenz dem richtigen Vorgang zu und speichert sie für die Vorlagenausfüllung.
- **[M] Manuelles Einfügen/Hochladen:** Der Anwalt kann den Mailtext einfügen oder die Nachricht als
  `.eml`/`.txt` hochladen. Dieser Weg funktioniert mit jedem Mail-Anbieter und ohne hinterlegten
  Zugang — er ist der garantierte Rückfall.
- **[S] Automatische Postfach-Überwachung:** Die App überwacht das Postfach des Anwalts und erfasst
  eingehende Zentralruf-Antworten selbsttätig (Erkennung über den Betreff), ereignisbasiert statt in
  starrem Takt. Voraussetzung ist ein einmalig hinterlegter Postfach-Zugang (siehe 7.1); ohne Zugang
  bleibt die Überwachung inaktiv. Beide Wege münden in dieselbe Auswertung.
- **[S] Anhänge der erfassten Antwort aufheben:** Bringt eine erfasste Antwort Dateien mit, hebt
  die App sie auf und bietet sie beim Versand zum Anhängen an (siehe 4.7). Beobachtet wurde, dass
  der Anwalt genau diese Dateien im Mailprogramm von Hand in die ausgehende Nachricht zieht — ein
  Schritt, den die App ihm abnehmen kann, weil sie die Nachricht ohnehin vollständig abruft.
  Aufgehoben wird nur, was zu einer erfassten Antwort gehört: Ein Posteingang zum Lesen und
  Verwalten entsteht dadurch nicht (Abschnitt 8). Aufgehoben heißt **nicht auf Dauer**: Was zwei
  Wochen unberührt liegt, räumt die App wieder weg — die Nachricht liegt ja weiter im Postfach,
  und ein Gutachten mit Lichtbildern soll sich nicht über Jahre in der Anwendung sammeln.
  *Ergänzt am 26.08.2026 nach Beobachtung in der Kanzlei; Aufbewahrungsgrenze am 27.08.2026.*
- **[M] Übernahme bleibt bestätigter Schritt:** Antworten werden dem passenden Vorgang
  *vorgeschlagen*; die Übernahme bestätigt der Anwalt. Unsichere Zuordnungen und Abweichungen
  zwischen Antwort und bereits erfassten Daten werden dabei sichtbar gemacht, nicht stillschweigend
  übernommen oder verworfen.
- **[M] Negativ-Antwort:** Kann der Zentralruf keinen Versicherer ermitteln, bleibt der Vorgang mit
  erkennbarem Stand offen. Die App bietet beide Auswege an:
  - **Anfrage wiederholen** — mit korrigierten Daten (z. B. Kennzeichen-Tippfehler) direkt aus dem
    Vorgang heraus, ohne alles neu zu erfassen.
  - **Versicherer manuell setzen** — Auswahl aus den bereits bekannten Versicherern (siehe 5.2)
    statt Abtippen; der Workflow läuft danach normal weiter.

### 4.4 Vorlage ausfüllen

Es existieren zwei Arten von Word-Vorlagen; der Nutzer wählt pro Schreiben aus
(„Auflistung vorhanden: ja/nein"):

1. **[M] Vorlage mit Auflistung:** Enthält eine Tabelle (Schadensaufstellung), die automatisch
   befüllt wird. Die **RVG-Anwaltskostenkalkulation** (Geschäftsgebühr nach Gegenstandswert gemäß
   § 13 RVG, aktueller Gebührenstand) wird im Dokument berechnet und eingetragen.
2. **[M] Vorlage ohne Auflistung:** Enthält stattdessen eine **HGN-Sektion** (Haftung dem Grunde
   nach).

Zur Vorlage mit Auflistung:

- **[M] Standardpositionen:** Eine neu begonnene Schadensaufstellung steht bereits mit den fünf
  üblichen Positionen da — in dieser Reihenfolge und in diesem Wortlaut: „Reparaturkosten netto
  nach Gutachten", „Wertminderung nach Gutachten", „Unkostenpauschale", „Abschleppkosten /
  Standgeldkosten", „Sachverständigenkosten". Die Beträge bleiben ab Werk leer; sie trägt der
  Anwalt ein.
- **[M]** In den Einstellungen (Reiter „Schadensaufstellung") legt der Anwalt
  Bezeichnungen **und** Beträge der Standardpositionen selbst fest; eine kleine Vorschau zeigt
  dort, wie die Tabelle damit startet. Ein hinterlegter Betrag wird nur vorbelegt und bleibt im
  Assistenten änderbar; „Zurücksetzen" führt auf die fünf üblichen Positionen zurück.
- **[M]** Jede dieser Positionen ist änderbar und löschbar, weitere lassen sich ergänzen. Auch eine
  gelöschte Standardposition kommt ohne Abtippen zurück. Die letzte verbliebene Zeile bleibt
  stehen — sonst stünde die Aufstellung ohne Eingabefeld da; ihr Text lässt sich leeren.
- **[M]** Eine Position ohne Betrag erscheint nicht im erzeugten Dokument — eine nicht gebrauchte
  Standardposition muss deshalb nicht gelöscht werden.
- **[M]** Eine zum Vorgang bereits gespeicherte Aufstellung hat Vorrang: Sie wird unverändert
  angezeigt, die Standardpositionen treten nicht an ihre Stelle.

Gemeinsam:

- **[M]** Platzhalter werden mit den erfassten Mandanten-, Unfall- und Versicherungsdaten befüllt.
- **[M]** Es darf kein unbefüllter Platzhalter im fertigen Dokument verbleiben, ohne dass der Nutzer
  darauf hingewiesen wird.
- **[M]** Welche Vorlagen zur Auswahl stehen und welche Felder sie besitzen, bestimmt der Anwalt
  selbst (siehe 5.3).

### 4.5 Prüfung und Korrektur

- **[M] Sichtprüfung:** Der Anwalt prüft das ausgefüllte Dokument in einer Vorschau in der App. Seine
  Freigabe ist Voraussetzung für Ablage und Versand.
- **[M] Korrekturmöglichkeit:** Das Dokument ist entweder direkt in der App änderbar **oder** lässt
  sich in einem externen Editor (z. B. MS Word) öffnen, in dem es bereits geladen ist.

### 4.6 Ablage in der Akte

- **[M]** Das freigegebene Dokument wird in der Akte des Mandanten abgelegt; ist noch keine Akte
  vorhanden, wird sie angelegt. Konventionen und Namensmuster siehe 6.1.
- **[M]** Der Ablageort wird am Vorgang festgehalten, damit das Dokument später wiederauffindbar ist.

### 4.7 Versand

- **[M] Verfassen und Senden in der App:** Die App stellt die Mail fertig zusammen — Empfänger,
  Betreff, Text und Anhänge — und **versendet sie auf Knopfdruck über das Postfach der Kanzlei**
  (derselbe Zugang wie bei der Überwachung, siehe 4.3). Gesendet wird erst nach einer
  ausdrücklichen Rückfrage, die Empfänger und Anhänge noch einmal auflistet; bis dahin bleibt
  alles änderbar. *Geändert am 25.08.2026: Bis dahin galt hier „Entwurf statt Direktversand" —
  die App bereitete nur vor und übergab an das Mailprogramm.*
- **[M] Empfänger:** Standardmäßig die gegnerische Versicherung und der Mandant, gemeinsam in
  **einer** Mail. Die Adressen, die die App schon kennt (Mandantenregister, Zentralruf-Antwort,
  Versicherer-Wissensbasis, siehe 5.1/5.2), sind mit einem Klick übernehmbar; jede weitere Adresse
  lässt sich eintippen und wieder entfernen.
- **[M] Anhang:** Das Anspruchsschreiben als **PDF**.
- **[S] Weitere Anhänge:** Zusätzlich lassen sich Dateien aus der Akte anhängen (Fotos, Gutachten,
  Rechnungen), ausgewählt beim Verfassen. Drei gleichwertige Wege, weil die Datei an drei Orten
  liegen kann: aus dem Fall-Ordner anklicken, aus der Dateiauswahl holen — oder **mit der Maus aus
  dem Explorer in den Entwurf ziehen**. Was nur in einer erhaltenen Nachricht steckt und nirgends
  auf der Platte liegt, holt die App auf Wunsch aus der gerade in Outlook geöffneten Nachricht.
  Jeder Anhang lässt sich vor dem Absenden öffnen und **nur für diese Mail** umbenennen; die Datei
  in der Akte behält ihren Namen. *Ergänzt am 27.08.2026: Beobachtet wurde, dass Anhänge in der
  Kanzlei mit der Maus zusammengesucht werden — ein Auswahldialog allein erzwingt einen Weg, den
  dort niemand geht.*
- **[S] Sichtprüfung vor dem Absenden:** Der Anwalt sieht die Mail so, wie sie beim Empfänger
  ankommt — Absender, Empfänger, Betreff, Anhänge unter ihren endgültigen Namen und der
  vollständige Text samt Signatur —, und zwar **während er sie schreibt**, nicht erst auf
  Nachfrage. Ist das Fenster zu schmal für eine zweite Spalte, bleibt die Vorschau auf Knopfdruck
  erreichbar. Das ist die Entsprechung zur Sichtprüfung des Dokuments (siehe 4.5): Der Versand ist
  der eine unumkehrbare Schritt des Ablaufs. *Ergänzt am 27.08.2026.*
- **[M] Alles oder nichts:** Fehlt ein Anhang, ist er gesperrt oder ist eine Adresse unbrauchbar,
  geht **nichts** hinaus, und der Grund steht im Klartext vor dem Anwalt. Eine Mail, der
  ausgerechnet das Anspruchsschreiben fehlt, wäre schlimmer als eine, die gar nicht erst hinausging.
- **[M] Betreff und Mailtext aus Vorlage:** Betreff und Anschreiben stammen aus einer vom Anwalt
  pflegbaren Textvorlage mit Platzhaltern (z. B. Zeichen, Mandantenname, Schadennummer) — je
  Empfängertyp eine eigene Vorlage. Ausgangsbestand ist die in der Kanzlei bereits verwendete
  Mailvorlage — sie wird einmalig übernommen, nicht nachgebaut. Solange diese Verwaltung nicht
  steht, belegt die App Anrede, Betreff und Bezugssatz aus den Vorgangsdaten vor; vor dem
  Absenden ist alles änderbar.
- **[S] Auch außerhalb des Schreibens:** Derselbe Entwurf lässt sich aus dem Postfach heraus
  öffnen — mit dem Vorgang der ausgewählten Antwort vorbelegt, sonst als leeres Anschreiben.
  Damit bleibt eine Nachfrage an die Versicherung in der App, ohne den Umweg über den
  Word-Assistenten. *(Grenzt an das Nicht-Ziel „keine Mandantenkommunikation über den
  beschriebenen Workflow hinaus" in Abschnitt 8: Ein Posteingang zum Lesen und Beantworten
  entsteht dadurch nicht.)*
- **[S] Entwurf im Mailprogramm als zweiter Weg:** Neben dem Direktversand öffnet die App die
  fertige Nachricht auf Wunsch als **Entwurf in Outlook** — mit Empfängern, Betreff, Text und den
  Anhängen, die sie kennt; gesendet wird dann dort. Gedacht für den Fall, dass noch etwas
  hinzukommt, das die App nicht hat: eine Datei aus einer anderen Nachricht, ein Satz, der im
  gewohnten Fenster schneller getippt ist. Zugleich die Rückfalltür, wenn der Direktversand
  scheitert. Ob und wann dort tatsächlich gesendet wurde, kann die App nicht wissen — der Anwalt
  bestätigt es beim Abschluss von Hand (siehe 4.8). Ist Outlook nicht verfügbar, genügt eine
  Entwurfsdatei, die das eingerichtete Mailprogramm öffnet; ersatzweise zeigt die App wie bisher
  das abgelegte Dokument im Ordner. *Geändert am 26.08.2026: Bis dahin zeigte die App für diesen
  Weg nur den Ablageordner. Beobachtet wurde, dass der Anwalt im Mailprogramm Anhänge aus der
  erhaltenen Nachricht in die ausgehende zieht — ein vorbereiteter Entwurf trifft diese
  Arbeitsweise, ein Ordnerfenster nicht.*
- **[M] Signatur:** Unter dem Anschreiben steht die Signatur der Kanzlei. Sie wird **nicht
  abgetippt**: Die App übernimmt die im Mailprogramm bereits eingerichtete Signatur einmalig in
  ihre Einstellungen und verwendet sie danach beim Direktversand; änderbar bleibt sie dort.
  Beim Entwurf im Mailprogramm setzt dieses seine eigene Signatur ein — die App fügt dort keine
  zweite hinzu. *Ergänzt am 26.08.2026.*
- **[M] Die Signatur geht so hinaus, wie die Kanzlei sie führt** — mit Schrift, Farben und
  Bildern, nicht als abgetippter Text. Übernommen wird die formatierte Fassung samt ihrer Bilder;
  daneben geht die Nur-Text-Fassung als Alternative mit, für Empfänger, deren Programm kein HTML
  anzeigt. Ist keine formatierte Fassung hinterlegt, bleibt es beim reinen Text.
  *Ergänzt am 27.08.2026: In der Signatur der Kanzlei stecken Bilder; ohne sie erkennt der
  Empfänger den Absender nicht wieder.*
- **[S] Schwere Signaturbilder je Mail weglassen:** In der Signatur steckt ein animiertes
  Werbebild von mehreren Megabyte, das **nicht** unter jeder Nachricht stehen soll. Beim
  Verfassen ist deshalb je Bild abwählbar, ob es mitgeht — mit seiner Größe daneben, denn ohne
  die Zahl ist die Frage nicht zu beantworten. Die hinterlegte Signatur bleibt davon unberührt;
  entschieden wird für die eine Mail. *Ergänzt am 27.08.2026: Bisher wurde das Bild dafür im
  Mailprogramm von Hand aus dem Entwurf gelöscht.*
- **[M] Größe der Nachricht vor dem Absenden:** Die App zeigt beim Verfassen, wie schwer die
  Nachricht ist und wie viel das Postfach durchlässt — Anhänge **und** Signaturbilder zusammen,
  denn beide gehen im selben Umschlag hinaus. Über der Grenze wird nicht gesendet, und die
  Meldung nennt die drei Auswege (weniger anhängen, verkleinern, Signaturbild weglassen). Ein
  Gutachten mit Lichtbildern reißt die üblichen Grenzen; das erst nach dem Absenden zu erfahren,
  hieße, es aus einer fremdsprachigen Serverantwort zu erfahren. *Ergänzt am 27.08.2026.*
- **[M] Versandnachweis in der App:** Die App hält je Vorgang fest, was hinausgegangen ist —
  Zeitpunkt, Weg, Empfänger, Betreff und die Anhangnamen, unter denen die Dateien beim Empfänger
  ankamen. „Ist das Anspruchsschreiben raus?" ist die Frage, die man an einer Vorgangsliste
  stellt; sie muss dort zu beantworten sein und nicht nur im Postfach. Der Eintrag entsteht
  **nach** der Einlieferung, nie davor.
  Der **Weg wird unterschieden**, und zwar sichtbar: Beim Direktversand hat die App die
  Einlieferung selbst gesehen und darf „versendet" behaupten. Bei der Übergabe an das
  Mailprogramm hat sie nur übergeben — ob dort abgeschickt wurde, erfährt sie nie (siehe 4.8).
  Ein Nachweis, der beides gleich aussehen lässt, wäre schlechter als keiner.
  Die Mail **selbst** legt die App weiterhin nicht ab: Sie liegt im Ordner „Gesendet" des
  Postfachs und damit im Mailprogramm am selben Konto. Der Nachweis ist der Index darüber, nicht
  ihr Ersatz — steht die Kopie dort ausnahmsweise nicht, muss auch das dabeistehen, sonst sucht
  der Anwalt umsonst.
  *Geändert am 29.08.2026: Bis dahin lautete der Punkt „[K] Kein Versandnachweis in der App — der
  Ordner ‚Gesendet' des Postfachs genügt als Nachweis". Das trifft für die Mail als Dokument
  weiterhin zu, nicht aber für die Auskunft: Der Ordner „Gesendet" beantwortet die Frage nach
  einem einzelnen Vorgang erst, wenn jemand ihn durchsucht, und über die Übergabe an das
  Mailprogramm sagt er gar nichts.*

### 4.8 Auftragsabschluss

- **[M] Abschluss ist ein eigener, bewusster Schritt** — unabhängig davon, ob und wann die Mail
  tatsächlich hinausging. Auch seit die App selbst versendet (siehe 4.7) bleibt der Abschluss
  davon getrennt: Er hängt nicht am Versand, sondern an der Entscheidung des Anwalts, dass der
  Auftrag erledigt ist — die Mail kann mehrfach hinausgehen (Mandant nachträglich,
  Korrekturschreiben), abgeschlossen wird genau einmal. Hat die App gesendet, ist die
  Bestätigung nur vorbelegt und begründet; wer außerhalb der App gesendet hat, setzt sie von
  Hand. *Geändert am 26.08.2026: Bis dahin lautete die Begründung „da die App den Versand dem
  Mailprogramm überlässt, kann sie den tatsächlichen Versandzeitpunkt nicht kennen“ — die
  Umstellung in 4.7 hat sie überholt, die Anforderung selbst nicht.*
- **[M]** Mit dem Abschluss
  - gilt der Vorgang als erledigt,
  - wird die laufende Auftragsnummer weitergezählt (siehe 7.1),
  - und der Vorgang wird ins Sachgebiete-/Auftragsregister aufgenommen (siehe 6.2).
- **[M]** Ein abgeschlossener Vorgang bleibt einsehbar und auffindbar.

### 4.9 Folgekorrespondenz

- **[M]** Zu einem offenen Vorgang lassen sich **weitere Schreiben** erstellen (Mahnung, Erinnerung,
  Korrektur des ersten Schreibens). Zeichen, Akte und Auftragsnummer bleiben unverändert; alle
  Schreiben landen im selben Unterordner.
- **[M]** Für ein Folgeschreiben stehen alle Daten des Vorgangs erneut vorbelegt bereit —
  einschließlich der Werte, die der Anwalt beim vorherigen Schreiben ergänzt oder korrigiert hat.
- **[S]** Am Vorgang ist erkennbar, welche Schreiben bereits erstellt wurden.

### 4.10 Erstkontakt über die Kanzlei-Website

Geplant ist eine Kanzlei-Website, auf der Interessenten ihre Unfalldaten (Kennzeichen, Unfalldatum,
Kontaktdaten) selbst eintragen. Ziel ist, dass diese Angaben in der App ankommen, ohne abgetippt zu
werden — fachlich der Einstieg **vor** 4.1.

- **[K] Einbahnstraße:** Der Kanal trägt Angaben ausschließlich **in die App hinein**. Von außen
  besteht kein Zugriff auf Mandanten, Vorgänge, Akten oder das Register (siehe 8).
- **[K] Eine Anfrage ist noch kein Mandat:** Eine eingegangene Website-Anfrage ist ein eigener
  Zustand *vor* dem Mandanten. Sie steht in einer eigenen Liste und verändert weder das
  Mandantenregister noch bestehende Vorgänge, solange der Anwalt sie nicht angenommen hat.
- **[K] Annahme per Klick:** Nimmt der Anwalt eine Anfrage an, entstehen daraus Mandant und Vorgang
  mit den bereits gefüllten Feldern — dieselbe Mechanik wie bei der Übernahme einer
  Zentralruf-Antwort (siehe 4.3): vorschlagen, bestätigen, korrigierbar. Abgelehnte Anfragen werden
  verworfen, ohne Spuren im Datenbestand zu hinterlassen.
- **[K] Datensparsam:** Nach der Entscheidung des Anwalts wird eine Anfrage außerhalb der App nicht
  weiter vorgehalten.

## 5. Stammdaten und Wissen

### 5.1 Mandantenregister

- **[M]** Die App führt ein Register der Mandanten mit ihren Stammdaten (Name/Anrede, Anschrift,
  Kontaktdaten, Notizen).
- **[M] Einmal erfassen, wiederverwenden:** Bei einem neuen Vorgang für einen bekannten Mandanten
  werden dessen Daten übernommen.
- **[M]** Einem Mandanten können mehrere **Kfz-Kennzeichen** und mehrere **Akten** zugeordnet sein.
- **[M]** Das Register ist die Grundlage für die Aktenablage (siehe 6.1) und für die
  Parteienbezeichnung „Mandant ./. Gegner" im Register (siehe 6.2).
- **[S] Duplikatschutz:** Tippt der Anwalt Daten ein, die zu einem bekannten Mandanten passen,
  weist die App darauf hin und bietet die Übernahme an — als Vorschlag, nicht als Automatik.

### 5.2 Versicherer

- **[S]** Die App merkt sich die Versicherer, die ihr aus Zentralruf-Antworten bekannt werden, samt
  Anschrift und Kontaktdaten.
- **[S] Lücken füllen:** Fehlen in einer Antwort Angaben (z. B. keine E-Mail-Adresse), ergänzt die
  App sie aus früherem Wissen zum selben Versicherer — mit erkennbarem Hinweis auf die Herkunft.
- **[S]** Bei einer Negativ-Antwort (siehe 4.3) kann der Versicherer aus dieser Liste gewählt werden.

### 5.3 Vorlagenverwaltung

- **[M]** Der Anwalt verwaltet seine **Word-Vorlagen selbst**, ohne dass ein Entwickler eingreifen
  muss: anlegen, ändern, entfernen.
- **[M]** Zu einer Vorlage gehören ein Name, die zugehörigen Word-Dateien (Variante mit und ohne
  Schadensaufstellung, siehe 4.4) sowie die Beschreibung der Felder, die beim Ausfüllen abgefragt
  und eingesetzt werden.
- **[M]** Die in einem Vorgang zur Auswahl stehenden Vorlagen ergeben sich aus dieser Verwaltung.
- **[M]** Ebenso pflegbar sind die **Mail-Textvorlagen** für den Versand (siehe 4.7).

## 6. Ablage und Register

### 6.1 Aktenablage im Dateisystem

- **[M] Akte je Mandant:** Vor dem Speichern prüft die App, ob für den Mandanten bereits eine Akte
  (Ordner) existiert. **Match-Kriterium: Mandantenname.**
  - Akte vorhanden → neuer Unterordner in der bestehenden Akte.
  - Akte nicht vorhanden → neue Akte anlegen, darin der Unterordner.
- **[M] Standard-Namensmuster** für den Unterordner:

  ```
  {Mandant}v{Unfalldatum} {Notiz}
  Beispiel: Müller v12.06.2026 Verkehrsunfall
  ```

- **[S] Konfigurierbares Muster:** Das Namensmuster ist in den Einstellungen mit Platzhaltern frei
  änderbar (u. a. `{Mandant}`, `{Gegner}`, `{Kennzeichen}`, `{Unfalldatum}`, `{Aktenzeichen}`,
  `{Auftragsnummer}`, `{Abteilung}`, `{Notiz}`), damit eine geänderte Kanzlei-Konvention keine
  Programmänderung erfordert. Ohne Änderung gilt das Standardmuster oben.
- **[M]** Der Stammordner des Aktensystems ist in den Einstellungen hinterlegt (siehe 7.1).

### 6.2 Sachgebiete-/Auftragsregister

Die Kanzlei führt ein fortlaufendes Register über alle bearbeiteten Aufträge. Ziel ist, dieses
Register ohne manuelles Nachtragen aktuell zu halten.

- **[M] Die App führt das Register.** Sie ist die führende Quelle; das bisherige Word-Dokument der
  Kanzlei wird abgelöst, nicht fortgeschrieben.
- **[M] Automatische Aufnahme:** Ein abgeschlossener Vorgang (siehe 4.8) erscheint als neue Zeile.
- **[M] Spaltenschema je Zeile:**
  - laufende Nummer
  - Zeichen (laufende Nr./Jahr samt Abteilung)
  - „Name ./. Gegner" samt Sachbestand/Datum
  - Rechtsgebiet
- **[M] In-App-Ansicht:** Die Registerdaten sind in der App im exakten Spaltenschema einsehbar.
- **[S] Export auf Knopfdruck:** Das Register lässt sich als Word- oder PDF-Tabelle im selben
  Spaltenschema ausgeben — für Ausdruck, Weitergabe oder Archivierung.

## 7. Betrieb

### 7.1 Einstellungen

Konfigurierbar sein müssen mindestens:

- **[M] Kanzlei-/Anfragerdaten** für die Zentralruf-Anfrage (Name, Anschrift, Kontaktdaten).
- **[M] Abteilungskürzel und laufende Auftragsnummer** für das Referenzformat (siehe 4.2):
  - **Hinterlegen:** Die aktuelle Nummer ist hier jederzeit einsehbar und korrigierbar.
  - **Vorbefüllen:** Jedes „Auftragsnummer"-Feld in der App wird automatisch mit ihr vorbelegt und
    kann für den einzelnen Vorgang überschrieben werden.
  - **Hochzählen:** Nach dem Auftragsabschluss (siehe 4.8) wird sie um eins erhöht — automatisch
    oder erst nach Bestätigung; welche Variante gilt, ist hier einstellbar.
- **[M] Sachgebietskatalog:** Die Abteilungskürzel der Kanzlei mit ihrem Sachgebiet liegen als
  Stammdaten in der App vor. Sie speisen die Auswahl der Abteilung (siehe 4.2) und des
  Rechtsgebiets (siehe 6.2) — beide Auswahlen bieten den vollen Katalog an, nicht nur die im
  Bestand vorkommenden Werte. Der Katalog (aus dem Kopf des Kanzlei-Registers, unverändert):

  | Kürzel | Sachgebiet | Kürzel | Sachgebiet |
  |---|---|---|---|
  | `C01`  | Zivilrecht (allgemein)   | `C05`  | Strafrecht |
  | `C01a` | Arbeitsrecht             | `C06`  | Verwaltungsrecht |
  | `C02`  | Familienrecht            | `C06a` | Ausländer- und Asylrecht |
  | `C03`  | Verkehrsrecht            | `C06s` | Sozialrecht |
  | `C03o` | Ordnungswidrigkeitssache | `C07`  | Sonstiges |
  | `C04`  | Verkehrsstrafrecht       | `C07m` | Markenrecht |

  Jeder Katalogeintrag **trägt ein Kürzel** — Einträge ohne Kürzel sind nicht erlaubt.
  Vertragsrecht kommt in der Sachgebietsspalte des gewachsenen Registers vor, hatte aber nie eine
  eigene Abteilung (die Zeilen liefen unter `C01`) und steht deshalb **nicht** im Katalog:
  Bestehende Werte bleiben wortgetreu erhalten und sichtbar; ein eigenes Kürzel kann es später
  über die Pflege (siehe unten) bekommen.
  - **[M] Überschneidungen:** Eine Abteilung kann neben dem Hauptsachgebiet ein Nebensachgebiet
    tragen, geschrieben als `Hauptkürzel/Nebenteil` (`C05/3` = Strafrecht mit Verkehrsbezug). Der
    Nebenteil ist das Kürzel des Nebensachgebiets ohne das Präfix `C0` (`C03` → `3`, `C03o` →
    `3o`, `C01a` → `1a`); die Rückabbildung setzt `C0` wieder davor. Beim Filtern zählt ein
    Vorgang zu einem Sachgebiet, sobald es als Haupt- **oder** Nebensachgebiet auftritt.
  - **[M] Normalisierung:** Kürzel werden ohne Leerzeichen geführt und beim Einlesen normalisiert
    (`C 03o` → `C03o`), denn das Referenzformat (siehe 4.2) trennt die Abteilung am Leerzeichen.
  - **[S] Pflegbar:** Kürzel und Sachgebiete sind in der App änderbar und erweiterbar — die
    Kanzlei pflegt ihren Katalog selbst. Bis dahin genügt der eingebaute Katalog.
- **[M] Stammordner des Aktensystems** und **[S] Namensmuster der Unterordner** (siehe 6.1).
- **[M] Mail-Textvorlagen** für den Versand (siehe 4.7). Die Empfänger wählt der Anwalt je Mail,
  sie sind keine Einstellung.
- **[S] Postfach-Zugang** für die automatische Überwachung (siehe 4.3): Postfach-Adresse,
  Zugangsdaten und Betreff-Filter. Ohne hinterlegten Zugang bleibt die Überwachung inaktiv.
- **[S] Darstellungsoptionen für erzeugte Dokumente** (z. B. Farbe der Tabellen-Titelzeile der
  Schadensaufstellung passend zum Kanzlei-Vorbild).
- **[M] Zugang zur Datensicherung** (siehe 7.2).

### 7.2 Datensicherung und Datenintegrität

- **[M] Schutz vor Datenverlust:** Erfasste Daten dürfen weder durch einen App-Neustart noch durch
  parallele Zugriffe verloren gehen oder inkonsistent werden.
- **[M] Sichern und Wiederherstellen:** Der Anwalt muss seine Daten aus der App heraus sichern und
  aus einer Sicherung wiederherstellen können — ohne IT-Kenntnisse.
- **[M] Robuste Wiederherstellung:** Eine ungültige oder beschädigte Sicherung darf den vorhandenen
  Datenbestand nicht zerstören; der Nutzer wird auf das Problem hingewiesen.
- **[S] Dauerhaft eindeutige Kennung:** Jeder Datensatz (Vorgang, Mandant, Antwort, Vorlage) trägt
  eine Kennung, die dauerhaft und über Installationsgrenzen hinweg eindeutig bleibt — nicht nur
  innerhalb des aktuellen Bestands. Nur so lassen sich Daten aus mehreren Quellen zusammenführen
  (Wiederherstellung aus einer Sicherung, Übernahme einer Website-Anfrage nach 4.10, ein späterer
  zweiter Arbeitsplatz), ohne dass Einträge kollidieren oder doppelt entstehen.
- **[S] Nachvollziehbarer Änderungsstand:** Zu jedem Datensatz ist festgehalten, wann er zuletzt
  geändert wurde. Im Alltag macht das den Stand eines Vorgangs ablesbar; darüber hinaus ist es die
  Voraussetzung, um bei Daten aus zwei Quellen zu erkennen, welcher Stand der neuere ist und wo sie
  sich widersprechen — statt eine Änderung stillschweigend zu verlieren (siehe 1.3).

### 7.3 Auslieferung und Aktualisierung

- **[M] Installation ohne IT-Kenntnisse:** Die App wird über ein gewöhnliches Windows-Setup
  installiert und ist danach über das Startmenü erreichbar (siehe auch 2, Ein-Klick-Betrieb).
- **[S] Einfache Aktualisierung:** Der Nutzer muss eine neue Version ohne Entwicklerhilfe einspielen
  können. **[M]** Dabei bleiben alle Daten und Einstellungen erhalten — eine Aktualisierung darf
  niemals den Datenbestand zurücksetzen.
- **[K] Aktualisierung aus der App heraus:** Die App weist auf eine verfügbare neue Version hin und
  aktualisiert sich nach Bestätigung selbst. Wünschenswert, aber nachrangig — der Weg über ein neues
  Setup genügt zunächst (Bezugsquelle für Updates siehe 9).

## 8. Nicht-Ziele / Abgrenzung

- **Keine vollständige Kanzleisoftware:** Kein Fristenmanagement, keine Buchhaltung, keine
  Mandantenkommunikation über den beschriebenen Workflow hinaus.
- **Keine Fristen- oder Wiedervorlagelogik:** Die App erinnert nicht aktiv an unbeantwortete
  Anfragen oder Schreiben. Die nach Bearbeitungsstand gruppierte Übersicht (siehe 3) genügt, um zu
  sehen, was offen ist.
- **Kein Mailprogramm:** Die App versendet die Mails des Workflows selbst (siehe 4.7), ersetzt aber
  kein Postfach: kein Posteingang zum Lesen und Beantworten, keine Ordner, keine Suche. Wer
  antwortet, tut das im gewohnten Mailprogramm.
- **Keine Vollautomatisierung ohne Anwalt:** Captcha-Lösung, inhaltliche Freigabe, Übernahme der
  Zentralruf-Antwort und Auftragsabschluss bleiben bewusst bestätigte Schritte.
- **Andere Rechtsgebiete zunächst nur getragen, nicht ausgebaut:** Über die gemeinsame Vorgangs-,
  Mandanten- und Registerverwaltung hinaus ist der durchgängig automatisierte Workflow (Zentralruf,
  RVG, Anspruchsschreiben) nur für Verkehrsunfall-Mandate ausgearbeitet.
- **Kein Mehrbenutzer- oder Netzwerkbetrieb:** Einzelplatz, ein Nutzer, lokale Daten.
- **Keine Auslagerung des Datenbestands:** Mandanten, Vorgänge, Akten und Register bleiben auf dem
  Rechner der Kanzlei. Sie werden nicht auf einen Server ausgelagert und nicht zwischen Geräten
  geteilt — die App bleibt ohne Internetverbindung arbeitsfähig, und der Umgang mit
  Mandantsgeheimnissen bleibt eine rein lokale Angelegenheit. Der Website-Kanal (siehe 4.10) ist
  davon keine Ausnahme: Er reicht nur unbestätigte Anfragen herein und gibt keine Bestandsdaten
  hinaus.

## 9. Offene Punkte (bewusst noch nicht entschieden)

| Thema | Stand |
|---|---|
| Offizielle Zentralruf-API für Anwälte als Alternative zur Browser-Automatisierung | Zu prüfen |
| Übernahme der bisherigen Registereinträge aus dem alten Word-Dokument der Kanzlei | Offen — zu klären, ob Altbestand migriert oder das Register ab jetzt neu geführt wird (siehe 6.2) |
| Bezugsquelle und Weg für Programm-Updates | Offen — Voraussetzung für die Aktualisierung aus der App heraus (siehe 7.3) |
| Ob und wie weitere Anhänge aus der Akte vorausgewählt werden (z. B. immer alle Fotos) | Offen (siehe 4.7) |
| Weg des Website-Kanals: strukturierte E-Mail an die Kanzlei (nutzt die vorhandene Postfach-Überwachung) oder Abholung von einem Formular-Dienst | Offen (siehe 4.10) |
| Welche Felder das Website-Formular abfragt und welche davon Pflicht sind | Offen (siehe 4.10) |
| Tiefergehender Ausbau weiterer Rechtsgebiete über die gemeinsame Verwaltung hinaus | Offen — wird erweitert, wenn beschlossen |
