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
`RegisterFilter` (Stand, Jahrgangs**spanne**, Herkunft, Rechtsgebiet).

Die **Herkunft** (`quelle`, gegen `RegisterQuellen`) ist der praktisch wichtigste Filter: Nach der
Übernahme besteht das Register zum größten Teil aus Historie, und wer die laufende Arbeit der
Kanzlei sehen will, sucht sie sonst zwischen tausenden Altzeilen.

Der Filter kennt **keinen `VorgangStatus` mehr**, sondern nur „abgeschlossen / laufend". Eine
Registerzeile trägt keinen Lebenszyklus: Die Historie hat nie einen gehabt, und vom Vorgang liefert
der Zeilen-Endpunkt nur `abgeschlossen`. Ein Dropdown mit „Angefragt … Versendet" über einer Liste,
die zum größten Teil aus Historie besteht, verspräche eine Auswahl, die es nicht gibt. Der
fünfstufige Chip in der Statusspalte bleibt trotzdem — aber nur an Zeilen der App: Er kommt aus dem
`VorgangCubit`, den die Seite ohnehin hält (`RegisterView.statusJeReferenz`). Eine **historische
Zeile trägt dort nur „Historie"** und sonst nichts (§6.2); was an ihr auffiel, steht im
Herkunftskasten des Bearbeiten-Dialogs.

Die Jahrgänge stehen als **Spanne** (`vonJahr`/`bisJahr`, beide einschließlich) und nicht mehr als
Chip je Jahr: Ein Registerbuch ab 2018 ergab eine Chipreihe, die breiter war als die Tabelle
darunter, und beantwortete die häufigste Frage („die letzten drei Jahre") gar nicht. Ohne gesetzte
Grenze zeigen die Felder „Von"/„Bis" die äußeren Jahrgänge des Bestands — die Spanne bleibt damit
ablesbar. Ein Klick auf einen Jahrgangs-Chip in der Historie-Zeile setzt `RegisterFilter.imJahr`.

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

Am Bildschirm steht die Folge trotzdem **umgekehrt**: `RegisterReihenfolge.neuesteZuerst` ist die
Vorgabe der Seite und liest dieselbe Liste rückwärts, weil fast immer die jüngsten Zeilen gesucht
werden — nach tausenden übernommenen stünden sie sonst ganz unten. Das ist ausdrücklich **keine**
zweite Sortierregel: `anwenden` ist ein `reversed`, kein `sort`. Ein laufender Vorgang ohne Nummer
steht im Bestand hinten am Jahrgang und rückt dadurch von selbst nach ganz oben. Die Word-/PDF-Datei
bleibt chronologisch vorwärts wie das Registerbuch; die Auswahl „Reihenfolge" in der Filterleiste
stellt am Bildschirm auf dieselbe Richtung zurück.

Eine Stelle rechnet weiter selbst: die **Startseiten-Karte**. Sie hat den Vorgangsbestand ohnehin im
Speicher und baut daraus `RegisterZeile.ausVorgang` (samt `VorgangJahrgang.fuer`), statt beim Öffnen
der Startseite einen zweiten Abruf zu machen. Sie zeigt nur die letzten fünf Vorgänge der App und
keine Historie; ihre Abbildung hängt an `register_zeile_test.dart`.

## Ein Klick im Register führt je Herkunft woanders hin

Die Registertabelle hat zwei Rückrufe, nicht einen: `onHistorieZeile` öffnet den Berichtigen-Dialog,
`onVorgangZeile` springt über `VorgangHervorhebungSignal` + `AutoTabsRouter` in Tab 7. Das Register
bleibt damit **Verzeichnis** — gepflegt wird ein Vorgang in der Verwaltung, und zwei Pflegeorte für
denselben Vorgang wären einer zu viel.

Das Signal ist bewusst **nicht** das `VorgangNavigationSignal`: Das trägt eine Vorauswahl für den
Word-Assistenten und wird dort verbraucht. Denselben Kanal zu nehmen hieße, dass ein Blick ins
Register den nächsten Word-Lauf umstellt.

`VorgaengeListe` verarbeitet das Signal und scrollt in **zwei** Schritten — anteilig springen, im
nächsten Bild mit `ensureVisible` zurechtrücken. Der Grund: `ListView.builder` baut nur, was
sichtbar ist, eine Zeile weit außerhalb hat gar keinen `BuildContext`, an dem `ensureVisible`
ansetzen könnte.

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

Die Leiste zeigt aber **nur, was dauerhaft gilt** — Konfliktkopie, fehlendes PDF, wohin zuletzt
geschrieben wurde. Der Ausgang eines *Laufs* geht über `RegisterSpiegelMeldung` an `Rueckmeldung`,
also oben rechts: Wer oben auf „Register jetzt schreiben" drückt, liest keinen roten Satz, der
unter tausenden Zeilen am Fuß der Seite steht. Und was die Leitung wirft, übersetzt schon
`ApiRegisterSpiegelDatasource` in einen deutschen Satz (`RegisterException`) — vorher stand der
Ausnahmetext von Dio im Wortlaut in der Meldung an den Anwalt.

**Der Export braucht seine eigene Uhr.** `network_module.dart` gibt drei Sekunden vor; Schreiben
heißt aber Word starten (kalt rund anderthalb Sekunden), wandeln und zwei Dateien umziehen. Ohne
das `receiveTimeout` von zwei Minuten in `ApiRegisterSpiegelDatasource` meldete der Bildschirm eine
Zeitüberschreitung, während der Dienst in Ruhe zu Ende schrieb — die eine Meldung, die zu einem
zweiten Druck verleitet, der dieselbe Arbeit noch einmal anstößt. Dieselbe Vorsorge trifft
`WordAutomationDatasource` (60 s) und `ZentralrufDatasource` (3 min).

## Der Bearbeiten-Dialog prüft von Hand — er hat kein reactive_forms

`VorgangBearbeitenDialog` arbeitet mit `TextEditingController`n, nicht mit einer FormGroup. Das
Kennzeichen des Mandanten geht beim Speichern so in den Bestand, **wie es eingegeben wurde** — nur
gestutzt (§4.2, geändert am 11.09.2026; bis dahin lief es durch `normalizeKennzeichen`, wie jedes
Kennzeichenfeld der App). Die Zuordnung einer Zentralruf-Antwort über das Kennzeichen hängt daran
nicht: `gleichesKennzeichen` vergleicht ohne Rücksicht auf die Schreibweise.

**Aufgehalten wird dabei nichts** (#130). Was die App nicht liest oder was mehrdeutig ist, geht
unverändert in den Bestand; `KennzeichenField.beanstandung` steht als
`VorgangDialogField.hinweisText` unter dem Feld, in der Aufmerksamkeitsfarbe statt in Rot. Der
Hinweis hängt an einem `ValueListenableBuilder` auf dem Controller und nicht am Speichern-Knopf:
Eine Prüfung erst beim Speichern hätte zu einem Wert, den der Dialog nur mitgebracht hat, nie etwas
gesagt.

## Löschen: zwei Richtungen, ein Vertrag (§6.3)

Seit §6.3 sind Vorgang und Registerzeile beim Löschen gekoppelt, und zwar in **beide** Richtungen —
`DELETE api/Vorgaenge?referenz=…&registerzeileBehalten=` löscht den Vorgang und entscheidet über die
gespiegelte Zeile, `DELETE api/RegisterHistorie/{id}` löscht eine historische Zeile für sich. Beide
Richtungen sitzen bewusst an verschiedenen Stellen der Oberfläche:

- **Vorgang löschen (Tab 7, `vorgaenge_verwalten_page.dart`)** fragt jetzt zusätzlich, ob die
  Registerzeile bleibt. Der bisherige `bestaetigen()`-Dialog (`bestaetigungs_dialog.dart`) ist dafür
  bewusst **nicht** erweitert worden — er ist die reine Ja/Nein-Rückfrage an Dutzenden Stellen der
  App, und eine dritte Auswahl dort hätte jeden dieser Aufrufe mitverändert. Stattdessen liefert
  `VorgangLoeschenDialog` (`presentation/widgets/vorgang_loeschen_dialog.dart`) dieselbe Bauart wie
  `VorgangAbschliessenDialog` aus `word_automation`: `AlertDialog` + `CheckboxListTile` für eine
  Rückfrage mit genau einer zusätzlichen Entscheidung. Er liefert `bool?` — `null` bei Abbruch,
  sonst die Entscheidung zur Registerzeile; vorbelegt ist `true` (behalten), die Antwort, die nichts
  zusätzlich löscht.
- **Registerzeile löschen (Tab 6, `register_view.dart`/`register_tabelle.dart`)** ist neu: Die
  Tabelle bekommt eine zusätzliche Spalte mit einem Papierkorb-Symbol (`RegisterTabelle.onLoeschen`),
  sichtbar nur, wenn ein Rückruf gesetzt ist — genau wie schon bei `onHistorieZeile`/`onVorgangZeile`.
  Das Symbol sitzt in einer eigenen `DataCell` mit eigenem `onTap`, das für **diese eine Zelle** das
  `onSelectChanged` der Zeile überschreibt (Verhalten von `DataCell.onTap` in der Quelle von
  Flutters `DataTable`, gepinnte Fassung 3.41.2: eine Zelle mit eigenem `onTap` ruft nie den
  Zeilen-Rückruf) — ein Klick
  auf den Papierkorb öffnet also nicht zusätzlich den Bearbeiten-Dialog oder springt in die
  Vorgangsverwaltung.

  `RegisterView._zeileLoeschen` entscheidet danach über `RegisterZeile.istHistorie`:
  - **Historie** geht für sich über `RegisterCubit.loescheHistorie` (neu, spiegelt `aendereHistorie`)
    → `RegisterHistorieRepository.loesche` → `DELETE api/RegisterHistorie/{id}`, mit gewöhnlicher
    Rückfrage („Registereintrag löschen?") und Erfolg/Fehlschlag über `Rueckmeldung` — derselbe
    Wortlaut-Stil wie beim Berichtigen.
  - **Vorgang** hat **keine** Auswahl „nur die Zeile": Der Dialog („Vorgang mitlöschen?") sagt, dass
    die Zeile den Vorgang nicht überleben kann, und lässt nur bestätigen, dass beides geht. Bestätigt,
    ruft er `RegisterView.onVorgangLoeschen` — eine Brücke zur Seite, denn die Ansicht kennt den
    `VorgangCubit` nicht (der gehört der Seite, wie schon `onVorgangOeffnen`). `RegisterPage`
    verdrahtet sie auf `VorgangCubit.loesche(referenz, registerzeileBehalten: false)` und lädt danach
    `RegisterCubit` neu, damit die Zeile aus der Tabelle verschwindet. Fehlschläge meldet der
    `VorgangCubit` wie jede andere Löschung über die app-weite `VorgangPersistenzFehlerCubit` — hier
    wird bewusst keine zweite Fehlermeldung gebaut.

`VorgangCubit.loesche`, `VorgangRepository.deleteVorgang` und `ApiVorgaengeDatasource.deleteVorgang`
tragen jetzt alle `registerzeileBehalten` (Vorbelegung `true`); `VorgangPersistenzFehler` trägt es
mit, damit „Erneut versuchen" nach einem Fehlschlag dieselbe Entscheidung wiederholt und nicht
stillschweigend auf „behalten" zurückfällt.

## Der Register-Hub trägt schon die Nutzdaten — anders als der vom Postfach

`RegisterHub` (`data/datasources/register_hub.dart`) ist eine zweite SignalR-Anbindung, gebaut nach
dem Muster von `MailboxHub` aus `mailbox` — eigener Hub (`/hubs/register`), weil das Register ein
anderer senkrechter Schnitt ist als das Postfach (dieselbe Begründung steht am Backend-`RegisterHub`).
Der Unterschied zum Postfach-Hub: `replyReceived`/`statusChanged` dort sind nutzdatenfrei und lösen
nur ein Nachladen aus (`MailboxInboxCubit.refresh()`); `registerPdfFertig` hier trägt direkt
`fertig`/`pdfPfad`/`fehler` — dieselben Feldnamen wie `RegisterSpiegelDto`. Ein Nachladen des ganzen
Zeilenbestands nur für einen Satz in der Spiegelleiste wäre Ballast, den `RegisterSpiegelCubit`
(`presentation/blocs/register_spiegel_cubit.dart`) sich spart: `_pdfNachgezogen` schreibt die Meldung
direkt in `RegisterSpiegelErgebnis.copyWith(...)`.

`pdfLaeuft` lebt ausschließlich am `RegisterSpiegelErgebnis`/`RegisterSpiegelDto` — eine `RegisterZeile`
trägt es nicht, das Feld sagt nichts über eine einzelne Zeile, sondern über den Spiegel als Ganzes.

**„PDF läuft" ist ausdrücklich kein Fehler.** `RegisterSpiegelLeiste` prüft `stand.pdfLaeuft` **vor**
`stand.pdfFehler` und zeigt bei `pdfLaeuft: true` einen eigenen Satz („… das PDF entsteht noch —
kommt von selbst nach"), nie den `pdfFehler`-Satz — auch wenn der (vertragswidrig) zufällig gesetzt
wäre. Der Vertrag garantiert zwar, dass beide sich ausschließen (direkt nach dem Export ist
`pdfFehler: null`, solange `pdfLaeuft: true` gilt), die Leiste sichert das aber defensiv noch einmal
ab, statt sich blind auf das Backend zu verlassen (§6.2 „Solange kein neues PDF liegt, liegt auch
kein altes").

Push ist wie beim Postfach **best-effort**: `RegisterHub.ensureConnected()` schluckt einen
fehlgeschlagenen Verbindungsaufbau still. Ohne Verbindung bleibt die Leiste beim zuletzt per REST
geladenen Stand stehen (`RegisterSpiegelCubit.ladeStand()`, aufgerufen beim Öffnen der Seite) — ein
`pdfLaeuft: true` löst sich dann erst beim nächsten manuellen Laden auf, nicht von selbst.
