# vorgaenge — Fallstricke

Was aus dem Steckbrief (`FEATURE.md`) herausfiel, weil es mehr als eine Zeile braucht.

## Das Register führt alle Vorgänge — die Datei nicht unbedingt

Bis #40 zeigte `RegisterPage` nur `status == versendet`. Jetzt steht dort **jeder** Vorgang, und
gefiltert wird über `RegisterFilter` (Status, Jahrgang, Rechtsgebiet).

**Der Filter wirkt nur auf den Bildschirm.** Was in die Word-/PDF-Datei kommt, entscheidet die
Einstellung `KanzleiSettings.registerExportFilter`. Das ist Absicht und keine Nachlässigkeit:
Die Datei liegt in aller Regel in einem synchronisierten Ordner und wird von anderen gelesen —
hinge ihr Inhalt am Bildschirmfilter, ergäben zwei Schreibvorgänge zwei verschiedene Register
unter demselben Namen, je nachdem, was zuletzt eingestellt war.

Wer die Sortierung ändert, ändert sie **zweimal**: `RegisterFilter.anwenden` (Ansicht) und
`RegisterZeilenBau.Aus` (Datei) müssen dieselbe Reihenfolge liefern. Dasselbe gilt für
`RegisterFilter.jahrgang` und `RegisterZeilenBau.Jahrgang` — sie leiten den vierstelligen Jahrgang
aus demselben zweistelligen `Vorgang.jahr` ab, und ein Auseinanderlaufen fällt niemandem auf, weil
beide Seiten für sich plausibel aussehen.

## Die laufende Nummer steht nicht im Zähler

Die Nummer einer Registerzeile stammt aus der geparsten Referenz (`ReferenzTeile`), nicht aus
`KanzleiSettings.laufendeAuftragsnummer` — der Abschluss zählt für den *nächsten* Vorgang hoch.
Ein noch nicht abgeschlossener Vorgang hat deshalb gar keine Nummer; in der Ansicht steht „—",
in der Datei ist die Zeile kursiv gesetzt und die Legende erklärt es.

## Der Register-Spiegel läuft im Backend, nicht hier

`RegisterSpiegelCubit` stößt nur an und zeigt an. Geschrieben wird in `RegisterSpiegelService`
(Backend), und zwar auch nach jedem Vorgangsabschluss — **hinter** dessen Transaktion. Ein
Frontend-Exporter könnte das nicht: Der Abschluss passiert im Word-Assistenten, und die
Registerseite ist dabei nicht offen.

Drei Dinge daran sind leicht zu übersehen; sie stehen ausführlich in
[`docs/DATENFLUESSE.md`](../../../../docs/DATENFLUESSE.md) (Kette 3) und an den Klassen selbst:

- Die Datei wird **woanders gebaut und zuletzt umbenannt** (`AtomareAblage`). Direkt im Zielordner
  zu schreiben hieße, dass ein Synchronisierungsdienst sie halbfertig hochlädt.
- **Unveränderte Bestände werden nicht neu geschrieben** (`RegisterSpiegelStand`, die Merkdatei im
  Backend — nicht zu verwechseln mit dem gleichnamigen früheren Frontend-Typ). Sonst füllt sich
  der Versionsverlauf in der Cloud mit identischen Fassungen — dasselbe Problem, das das abgelöste
  Kanzleidokument bei Revision 5341 hat, nur an neuer Stelle.
- Der Knopf auf der Seite **erzwingt** (`erzwingen: true`), der automatische Lauf nicht. Hinter dem
  Knopf steht in aller Regel „die Datei ist weg oder sieht falsch aus"; ein „nichts zu tun" wäre
  darauf die unbrauchbarste aller Antworten.

**Ein Fehlschlag beim Spiegel darf den Abschluss nie mitreißen.** `RegisterSpiegelService` meldet
erwartbare Fehler (Zieldatei in Word geöffnet, kein Word installiert) als *Ergebnis* statt als
Ausnahme, und `VorgangAbschlussService` schluckt zusätzlich, was trotzdem herauskäme. Wer daran
etwas ändert, prüft `Abschliessen_BleibtBestehen_WennDerSpiegelScheitert` im Backend.

## Konfliktkopien sind eine Warnung, kein Schönheitsfehler

`RegisterSpiegelAblage.Konfliktkopien` sucht bei jedem Lauf flach nach Dateien, die wie
„Register-LAPTOP.docx" aussehen. Taucht eine auf, hat jemand den Spiegel unterwegs bearbeitet —
ab da gäbe es zwei Register, und genau davor will die Kanzlei weg. Die `RegisterSpiegelLeiste`
zeigt das deshalb in Fehlerfarbe und nicht als Nebensatz.
