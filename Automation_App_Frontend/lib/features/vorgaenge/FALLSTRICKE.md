# vorgaenge — Fallstricke

Was aus dem Steckbrief (`FEATURE.md`) herausfiel, weil es mehr als eine Zeile braucht.

## Zeichen und Referenz: zwei Namen, zwei Aufgaben

`Vorgang.referenz` ist der **Schlüssel** — `216/26 C03_EU-FE 1111`, mit angehängtem Kennzeichen.
Er steht in Suchen, im Zentralruf-Formular, in HTTP-Parametern und in Widget-Keys.
`Vorgang.zeichen` ist der **Name** — `216/26 C03` — und das, was der Anwalt sagt und schreibt.

**In der Oberfläche steht das Zeichen** (§4.2), über `ZeichenText` bzw. `vorgang.zeichen`; wo nur
eine Zeichenkette vorliegt, über `ReferenzTeile.zeichenAus(referenz)`. Die volle Referenz erscheint
nur, wo das Kennzeichen die Frage beantwortet: im Zentralruf-Formular, beim Zuordnen einer Antwort
und als Nebenzeile auf der Vorgangskachel. `test/architecture/zeichen_anzeige_test.dart` hält das
fest und führt die Ausnahmen namentlich.

Der Rückfall zählt: Lässt sich die Referenz nicht zerlegen (freihändig eingetragen), *ist* das
Zeichen die volle Referenz. Deshalb prüfen Kachel und Dashboard vor der Nebenzeile auf
Ungleichheit — sonst stünde dieselbe Zeichenkette zweimal untereinander. Dieselbe Antwort muss
`RegisterZeilenBau.Zeichen` im Backend geben, sonst zeigt der Bildschirm ein anderes Zeichen als
die Register-Datei.

## Das Register führt alle Zeilen — die Datei nicht unbedingt

Bis #40 zeigte `RegisterPage` nur `status == versendet`. Jetzt steht dort **jede** Zeile: jeder
Vorgang der App und, seit #109, die übernommene Registerhistorie der Kanzlei. Gefiltert wird über
`RegisterFilter` (Stand, Jahrgang, Rechtsgebiet).

Der Filter kennt **keinen `VorgangStatus` mehr**, sondern nur „abgeschlossen / laufend". Eine
Registerzeile trägt keinen Lebenszyklus: Die Historie hat nie einen gehabt, und vom Vorgang liefert
der Zeilen-Endpunkt nur `abgeschlossen`. Ein Dropdown mit „Angefragt … Versendet" über einer Liste,
die zum größten Teil aus Historie besteht, verspräche eine Auswahl, die es nicht gibt. Der
fünfstufige Chip in der Statusspalte bleibt trotzdem: Er kommt aus dem `VorgangCubit`, den die Seite
ohnehin hält (`RegisterView.statusJeReferenz`).

**Der Filter wirkt nur auf den Bildschirm.** Was in die Word-/PDF-Datei kommt, entscheidet die
Einstellung `KanzleiSettings.registerExportFilter`. Das ist Absicht und keine Nachlässigkeit:
Die Datei liegt in aller Regel in einem synchronisierten Ordner und wird von anderen gelesen —
hinge ihr Inhalt am Bildschirmfilter, ergäben zwei Schreibvorgänge zwei verschiedene Register
unter demselben Namen, je nachdem, was zuletzt eingestellt war.

## Reihenfolge und Zellen: eine Quelle, und die liegt im Backend

Bis #109 leitete die Ansicht ihre Zellen aus `Vorgang` ab (`parteienBezeichnung`,
`registerSachbestand`, `RegisterFilter.jahrgang`) und die Datei dieselben aus `RegisterZeilenBau` im
Dienst. Zwei Rechnungen für dasselbe Ergebnis, deren Auseinanderlaufen niemandem auffiel, weil jede
Seite für sich plausibel aussah — dagegen stand ein eigener Paritätstest im Testordner.

Er ist **weg, weil die zweite Quelle weg ist**: `GET /api/Vorgaenge/register/zeilen` liefert
die fertigen Zeilen samt Sortierung (Jahrgang aufsteigend, darin laufende Nummer, Zeilen ohne Nummer
hinten am Jahrgang). `RegisterFilter.anwenden` **filtert nur** und rührt die Reihenfolge nicht an.
Wer an der Sortierung etwas ändert, ändert `RegisterZeilenBau.Aus` — einmal.

Eine Stelle rechnet weiter selbst: die **Startseiten-Karte**. Sie hat den Vorgangsbestand ohnehin im
Speicher und baut daraus `RegisterZeile.ausVorgang` (samt `VorgangJahrgang.fuer`), statt beim Öffnen
der Startseite einen zweiten Abruf zu machen. Sie zeigt nur die letzten fünf Vorgänge der App und
keine Historie; ihre Abbildung hängt an `register_zeile_test.dart`.

## Eine historische Zeile wird zum Bearbeiten roh geladen, nicht zurückgerechnet

Der Zeilen-Endpunkt liefert die **Anzeigeform** — `RegisterHistorieAnzeige` im Backend setzt
Zeichen, „Sache" und „Sachbestand" aus den Einzelfeldern zusammen. `PUT /api/RegisterHistorie/{id}`
erwartet aber die Einzelfelder (Abteilung, Sachart, Mandant, Gegner, Sachbestand, Unfalldatum,
Rechtsgebiet). Deshalb holt der Dialog vor dem Öffnen `GET /api/RegisterHistorie/{id}`
(`RegisterHistorieZeile`) und belegt die Felder daraus vor — nie aus der Anzeigezeile. Eine
Rückrechnung aus „Bußgeldsache Erika Musterfrau" wäre nur an der Endung *-sache* vom bloßen Namen
zu unterscheiden gewesen; aus „Max Mustermann" wäre die Sachart „Max" geworden. Der Herkunftskasten
zeigt den `freitext` der Originalzeile als Beleg, dazu Befunde und Hinweise.

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

## Der Bearbeiten-Dialog prüft von Hand — er hat kein reactive_forms

`VorgangBearbeitenDialog` arbeitet mit `TextEditingController`n, nicht mit einer FormGroup. Das
Kennzeichen des Mandanten wird deshalb **beim Speichern** geprüft: `normalizeKennzeichen` zieht die
Schreibweise gerade, und was `istKennzeichen` nicht lesen kann, wird gar nicht erst gespeichert —
der Dialog bleibt offen und zeigt `KennzeichenField.hinweis` als `errorText` am Feld
(`VorgangDialogField.errorText`).

Ohne das wäre dies der eine Weg, auf dem ein Rohwert in den Bestand käme: Beim Erfassen stellt
`KennzeichenField` die Konvention selbst her, hier stand das Feld ungeprüft da. An dem Wert hängt
die Zuordnung einer Zentralruf-Antwort über das Kennzeichen (`gleichesKennzeichen`).
