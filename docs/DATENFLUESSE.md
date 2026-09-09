# Datenflüsse — was durch mehrere Features läuft

Die Steckbriefe (`FEATURE.md`) enden am Feature-Rand, die Fachlogik nicht. Sechs Ketten laufen
quer durch den Baum, und in keiner steht an der Nahtstelle, dass es eine gibt. Wer eine davon
ändert, ohne sie zu kennen, ändert sie an einer Stelle und lässt die anderen stehen.

Diese Datei ist **kein** Ersatz für die Steckbriefe: Sie sagt nur, welche Features zusammenhängen
und wo die Naht liegt. Was ein einzelnes Feature tut, steht weiter in seinem `FEATURE.md`.

## 1. Vom Platzhalter zum ausgefüllten Feld

Der Weg, den ein `{{Platzhalter}}` aus der Word-Vorlage bis zum fertigen Wert nimmt.

```
form_template_setup ──▶ vorgaenge ──▶ mandanten / zentralruf_reply ──▶ word_automation
                                                              └──▶ email_versand
```

- **Einrichten:** `FeldDatenquelleErkennung` (`form_template_setup/domain/services/`) löst den
  Platzhalternamen zu einer `FeldDatenquelle` auf und schlägt sie im Editor vor. Der Anwalt sieht
  und ändert den Vorschlag; gewählt wird er auf `FieldData.datenquelle`.
- **Ausfüllen:** `VorgangPrefillMatcher` (`vorgaenge/domain/services/`) löst dieselbe
  `FeldDatenquelle` zum Wert auf — und greift auf die Erkennung zurück, wo an einem Bestandsfeld
  nie eine Quelle gesetzt wurde.
- **Quellen:** `Vorgang` (vorgaenge), `Mandant` (mandanten) und die übernommene
  `ZentralrufReplyData` (zentralruf_reply). Zusammengesetzt wird in `mandant_anschrift.dart` —
  das liegt bei `vorgaenge`, nicht bei `mandanten`: Es dient der Vorbelegung, nicht dem Register.

- **Zweiter Verbraucher: die Mail-Textvorlagen** (§4.7). `MailVorlagenFueller`
  (`email_versand/domain/services/`) benutzt dieselbe Kette über
  `VorgangPrefillMatcher.wertFuerNamen` — bewusst dieselben Namen und dieselbe Schreibweise
  `{{…}}`, damit niemand zwei Kataloge im Kopf behalten muss. Eigen sind ihm nur `{{Anrede}}`,
  `{{Zusatzgruß}}` und die **Beugungen** (`{{Mandant/Mandantin}}`): Alle drei entstehen beim
  Verfassen **dieser einen Mail** und stehen nicht am Vorgang, werden deshalb vor der Kette
  beantwortet. Eine Beugung geht dabei gar nicht in den Katalog — sie trägt ihre Formen selbst und
  braucht nur die Anredeart. Dazu die Regel, dass eine Zeile ohne gefüllten
  Platzhalter ganz entfällt — die gilt nur für Mails, nicht für Word; was dabei übersprungen wurde,
  trägt `PlatzhalterBefund` mit Stelle und Folge weiter in den Dialog.
  **Die Beugung endet an der Mail:** Word füllt das Backend über `FieldData.label`, dort bleibt
  `{{Mandant/Mandantin}}` als Platzhalter im Dokument stehen und kommt als Warnung zurück.

**Die Naht:** Die `FeldDatenquelle` ist die einzige Verbindung zwischen Einrichten und Ausfüllen.
Ein neuer Wert dort braucht **beide** Seiten — ohne den Zweig im Matcher steht die Quelle im
Dropdown und liefert zur Laufzeit nichts. Einzelheiten in der `FALLSTRICKE.md` von
`form_template_setup`.

## 2. Von der Antwortmail zum Vorgang

```
Postfach ──▶ ZentralrufReplyParser ──▶ mailbox ──▶ vorgaenge ──▶ versicherer
```

- **Backend:** Der Monitor hängt per IMAP IDLE am Postfach, schickt den Treffer durch
  `ZentralrufReplyParser`, legt ihn im `DbReceivedReplyStore` ab und meldet ihn über den
  SignalR-Hub `MailboxHub`. `VersichererWissen` lernt dabei den Versicherer mit.
- **Frontend:** `mailbox_inbox_view.dart` ruft `VorgangCubit.uebernehmeAntwort` — die Übernahme
  legt einen Vorgang an oder ergänzt einen vorhandenen.
- **Ergänzung:** `versicherer_ergaenzung.dart` (in `zentralruf_reply`) füllt aus dem Register, was
  die Antwort offengelassen hat, je Feld mit Herkunftshinweis.

**Die Naht:** Derselbe Parser bedient zwei Eingänge — das Postfach und das Einfügen von Hand
(`POST api/Zentralruf/antwort/parse`). Wer am Parsen etwas ändert, ändert beide Wege. Und weil das
Backend den Versicherer erst **beim Parsen** lernt, lädt die Oberfläche danach ein zweites Mal
(`ladeErneut`); diese Doppelberechnung ist Absicht.

## 3. Vorgang abschließen

```
word_automation ──▶ vorgaenge ──▶ settings
                        └──▶ Register-Spiegel (Datei im Ablageordner)
```

`wizard_step_save.dart` schließt den Vorgang ab; im Backend erledigt `VorgangAbschlussService`
Status, Abschlusszeitpunkt und das Hochzählen der laufenden Auftragsnummer in **einer**
Transaktion, idempotent (§4.8, §7.1). Danach — und ausdrücklich erst danach — schreibt
`RegisterSpiegelService` das Sachgebiete-Register neu (§6.2).

**Der Abschluss wartet dabei auf nichts** (§4.8, seit 09.09.2026). Vermessen am Bestand der
Kanzlei: 93 Seiten, rund 2.000 Zeilen, 0,8 s für die `.docx` und 20,2 s für die PDF-Umwandlung
durch Word (linear, ~0,23 s je Seite). Der Anstoß ist deshalb abgesetzt — und zwar **mit eigenem
Scope** (`IServiceScopeFactory`), nicht als blanker Fire-and-Forget: Der Spiegel liest über den
`DbContext` der Anfrage, und der ist nach der Antwort abgeräumt. Ein abgesetzter Lauf auf dem
alten Scope hätte still ein „Cannot access a disposed context instance" gefangen und wortlos
keine Datei geschrieben — die schlimmste Sorte Fehlschlag, weil die Oberfläche Erfolg meldet.

**Innerhalb des Spiegels dann noch einmal geteilt:** Die `.docx` entsteht und zieht sofort in den
Ablageordner, das PDF danach über eine Warteschlange (`RegisterPdfWarteschlange`,
`RegisterPdfNachzug` als Hintergrunddienst) — im Auftrag stehen nur Pfade, aus demselben Grund wie
oben. Bis das neue PDF liegt, liegt **kein** PDF: Ein PDF von gestern neben einer `.docx` von heute
sieht vollständig aus und ist es nicht, und unterwegs liest man das PDF. Fertig oder gescheitert
meldet der Nachzug über `RegisterHub` (`/hubs/register`, `registerPdfFertig`); solange er läuft,
sagt `pdfLaeuft` im Stand, dass die Fassung entsteht — das ist ausdrücklich kein Fehler und wird
in der Oberfläche auch nicht als solcher gezeigt. Überholte Aufträge (fünf Abschlüsse am
Feierabend) überspringt der Nachzug anhand des Fingerabdrucks, vor **und** nach der Wandlung.

**Die Naht:** Die Auftragsnummer gehört fachlich zu `settings`, wird aber hier weitergezählt. Sie
von außen zu setzen (`POST api/Settings/auftragsnummer/erhoehe`) und den Abschluss zu trennen,
zerlegt genau die Transaktion, die dieser Dienst zusammenhält.

**Die zweite Naht — der Register-Spiegel:** Er hängt hinten an, und diese Reihenfolge ist die
eigentliche Zusicherung. Ein gesperrter Ablageordner (das Register ist in Word offen), ein
fehlendes Word oder ein volles Laufwerk dürfen einen abgeschlossenen Auftrag nicht wieder
aufmachen — der Spiegel ist eine Kopie, die Datenbank ist das Register. Deshalb meldet
`RegisterSpiegelService` erwartbare Fehlschläge als *Ergebnis* statt als Ausnahme, und der
Abschlussdienst schluckt zusätzlich, was trotzdem herauskäme.

Drei Eigenheiten hängen daran, alle drei an der Cloud und keine davon in der Cloud:

- **Gebaut wird woanders, umgezogen wird am Ende.** Ein Synchronisierungsdienst reagiert auf
  Dateiänderungen, nicht auf „fertig geschrieben" — würde die `.docx` direkt im synchronisierten
  Ordner entstehen, begänne er sie halbfertig hochzuladen. `AtomareAblage` baut im
  `RegisterSpiegelBauordner` und benennt zuletzt um; das ist auf demselben Laufwerk ein einziger,
  unteilbarer Schritt.
- **Unverändert heißt: nicht anfassen.** Das abgelöste Kanzleidokument steht bei Revision 5341.
  Ein Spiegel, der bei jedem Abschluss stumpf neu schreibt, erzeugt dasselbe in Neu — nur im
  Versionsverlauf der Cloud. `RegisterSpiegelStand` vergleicht einen Fingerabdruck über die Zeilen.
- **Zwei Originale sind der eigentliche Feind.** Die Datei trägt deshalb einen Hinweis im Text
  („gepflegt wird in der App"), bekommt Schreibschutz, und `RegisterSpiegelAblage` sucht bei jedem
  Lauf nach Konfliktkopien daneben. Der Hinweis im Dokument ist der einzige dieser drei Schutze,
  der auch auf dem Handy ankommt.

Was in die Datei kommt, entscheidet die Einstellung `registerExportFilter` — **nicht** der Filter
auf der Registerseite. Der wirkt nur auf den Bildschirm; sonst hinge der Inhalt einer Datei, die
andere lesen, davon ab, was zuletzt jemand eingestellt hatte.

**Seit #109 eine zweite Quelle:** Was der Spiegel schreibt und die Registeransicht zeigt, baut
`RegisterZeilenBau` aus **zwei** Quellen zusammen — den abgeschlossenen Vorgängen aus dieser Kette
und der importierten `RegisterHistorie` (Kette 6). Beide laufen in derselben Funktion zusammen,
damit Bildschirm und Spiegel weiterhin per Konstruktion dasselbe zeigen, nicht nur zufällig.

## 4. Kanzleidaten

```
settings ──▶ vorgang_starten ──▶ zentralruf_request
        └──▶ word_automation (Briefkopf)   └──▶ email_versand (Signatur)
```

`KanzleiSettings` ist der Einzelsatz mit Anschrift, Auftragsnummer und Mail-Signatur. Drei
Verbraucher: `vorgang_starten_bloc.dart` baut daraus den **Anfrager** für das
Zentralruf-Formular, `word_automation` füllt Briefkopf-Platzhalter, `email_versand` hängt die
Signatur an.

**Die Naht:** `ZentralrufAutomationService.ResolveAnfrager` nimmt den vom Frontend gesendeten
Anfrager bevorzugt und füllt **feldweise** aus `ZentralrufOptions.Anfrager` auf. Dieser Rückfall
greift wirklich — `vorgang_starten_bloc.dart` schickt `null`, wenn das Backend die Einstellungen
gerade nicht liefern konnte —, er trägt aber nur noch seine Klassenvorgaben (Personentyp
„Rechtsanwalt", Rest leer). In der versionierten `appsettings.json` stand derselbe Abschnitt
zusätzlich mit leeren Feldern für Name, Anschrift und Telefon des Anwalts: kein anderes Verhalten,
nur eine Einladung, personenbezogene Daten in ein öffentliches Repository zu schreiben. Er ist
entfernt — der Rückfall selbst bleibt.

## 5. Der Stand wechselt den Arbeitsplatz

Bereitstellen-Knopf / Beenden / Vorgangsabschluss / Zeitgeber → fertiges Archiv im gemeinsamen
Ordner → OneDrive-Übertragung → Prüfung und bestätigte Übernahme → Ansichten neu laden.

Die Datenbank bleibt lokal (§7.2). `AutomatischeSicherung` stellt Datenbank, Vorlagen und erfasste
Mailanhänge als geprüftes ZIP bereit; der andere Rechner wird über seine Arbeitsplatz-Datei
informiert. `ArbeitsplatzUebergabeGate` fragt beim Start, `SynchronisationsLeiste` prüft im Betrieb
alle 15 Sekunden und bei Wiederaufnahme. Ein später eintreffender Download bleibt damit sichtbar.

**Die Naht — Herkunft und Inhalt:** `SynchronisationsVerlauf` merkt die lokale Ausgangsbasis.
`BestandsFingerabdruck` unterscheidet echte Änderungen von WAL-/Checkpoint-Aktivität; unveränderte
Inhalte erhalten kein neues Archiv und keine neue Revision. Vorgängerkennungen erkennen
Nachfolger unabhängig von der Rechneruhr. Getrennte Zweige werden als Konflikt gemeldet.

**Die zweite Naht — Übernehmen ersetzt:** Die Zustimmung trägt eine `pruefkennung`, die an den
angezeigten fremden und lokalen Stand gebunden ist. Ein Konflikt braucht eine ausdrückliche
Auswahl. Import validiert und migriert eine isolierte Kopie, legt eine Vor-Import-Sicherung an
und tauscht dann die Datenbank über SQLite Online Backup. `ImportDateien` nimmt vorbereitete
Dateiänderungen bei abgefangenen Fehlern zurück. Ein harter Absturz über mehrere Dateien bleibt
über die Vor-Import-Sicherung wiederherstellbar.

**Die dritte Naht — alte Ansichten:** `DatenstandSignal` baut nach Import Router und Formulare neu.
`DatenbankWechsel` verhindert spätere Saves alter EF-Kontexte; `DatenstandMiddleware` und
`DatenstandInterceptor` verhindern Schreibaufträge mit einer veralteten Datenstand-Kennung.
Ungespeicherte Eingaben müssen vor einer Übernahme gespeichert werden.

**Die vierte Naht — Pfade:** Relative OneDrive-Einstellungspfade bleiben portabel, absolute
Einstellungspfade behalten den lokalen Wert. Erfasste Anhänge reisen mit relativen Archivpfaden;
Akten-/Dokumentverweise unter dem Aktenstamm werden am Ziel angepasst. Die Akten selbst liegen in
der separat synchronisierten Aktenablage. Postfach-Zugänge und Tokens bleiben rechnerlokal.

**Die Rückmeldung:** „Bereitgestellt“ bestätigt die lokale Ablage und keinen Cloud-Upload.
Dateigröße und Prüfsumme werden beim Übernehmen geprüft; ein Platzhalter allein ist kein Beweis
für einen vollständigen Download. Eine Übernahme wird im gemeinsamen Ordner quittiert. Die
letzte automatische Sicherung bleibt lokal vermerkt und Fehler werden sichtbar. Der Zeitgeber
arbeitet weiter alle 30 Minuten, die Aufbewahrung staffelt eigene Archive nach Tag/Woche/Monat.

Einrichtung und Alltag stehen in [Arbeitsplatzwechsel](ONEDRIVE_ARBEITSPLATZWECHSEL.md), technische
Details im [Backup-Steckbrief](../Automation_App_Frontend/lib/features/backup/FEATURE.md).

## 6. Registerhistorie einlesen

```
Datei ──▶ POST /api/RegisterImport (Vorschau/Übernahme) ──▶ Tabelle RegisterHistorie
                                                                    └──▶ RegisterZeilenBau
                                                                           ├──▶ GET .../zeilen
                                                                           └──▶ Register-Spiegel (Kette 3)
```

Ein Programm auf dem Kanzleirechner (oder ein Agent) liest den Altbestand aus dem bisherigen
Word-Dokument der Kanzlei jahrgangsweise aus und schickt ihn als Datei an
`POST /api/RegisterImport` — ohne `uebernehmen` nur eine Prüfung, mit `uebernehmen=true` derselbe
Code, der schreibt (§6.2, Format in `docs/REGISTER_IMPORT.md`), wahlweise je Jahrgang einzeln
oder für alle Jahrgänge einer Datei zusammen. Übernommene Zeilen landen in der eigenen Tabelle
`RegisterHistorie`, wiedererkannt über Jahr, laufende Nummer **und** Nummernzusatz — **nicht** in
der Vorgangs-Tabelle, sonst stünden Tausende Zeilen ohne zugehörigen Vorgang in der Vorgangsliste.

`RegisterZeilenBau` (Backend-Slice `Vorgaenge`) liest beide Tabellen und baut daraus **eine**
Zeilenliste, sortiert nach Jahrgang und laufender Nummer: `GET api/Vorgaenge/register/zeilen`
liefert sie an die Registeransicht (Frontend `vorgaenge`), derselbe Bau speist den
Register-Spiegel aus Kette 3.

**Die Naht:** `RegisterZeilenBau` ist die einzige Stelle, die beide Quellen kennt. Ein neues Feld
an einer Quelle (Vorgang oder Historie), das in der Zeile erscheinen soll, muss dort eingetragen
werden — sonst zeigen Bildschirm und Spiegel die eine Quelle vollständig und die andere nur
teilweise, ohne dass ein Test das bemerkt.

**Seit §6.3 läuft die Kante auch in die andere Richtung** (09.09.2026): Nicht nur speist die
Historie die Registerzeilen, sie **nimmt** auch eine auf. Wird ein Vorgang gelöscht und soll seine
Registerzeile bleiben (`DELETE api/Vorgaenge?…&registerzeileBehalten=true`), macht
`VorgangLoeschung` aus der gespiegelten Zeile eine eigenständige Zeile der Historie — mit
`Quelle = "vorgang"` statt `"import"`, damit ablesbar bleibt, woher sie kam. Zwei Dinge hängen
daran:

- **Gebaut wird über `RegisterZeilenBau.Zeile`**, dieselbe Ableitung wie für Ansicht und Spiegel.
  Eine zweite Herleitung von Jahrgang, Zeichen und Rubrum wäre genau die Verdopplung, die diese
  Klasse verhindern soll.
- **Der natürliche Schlüssel ist eindeutig** (`Jahr`, `LaufendeNummer`, `NummerZusatz`, Unique-Index
  mit Filter `LaufendeNummer > 0`). Die Übernahme fragt **vorher**, ob er belegt ist, und lässt es
  dann bleiben — steht die Zeile schon im Register, gibt es nichts zu bewahren. Eine
  `DbUpdateException` mitten in einem Löschvorgang wäre der schlechteste Ausgang, und der Vorgang
  soll trotzdem verschwinden.

Die Gegenrichtung braucht keinen eigenen Weg: Eine Spiegelzeile kann ihren Vorgang nicht
überleben — sie käme beim nächsten Schreiben wieder —, deshalb löscht die Registeransicht sie über
denselben Aufruf mit `registerzeileBehalten=false`. Nur eine echte historische Zeile hat einen
eigenen Weg (`DELETE api/RegisterHistorie/{id}`).

## Wo eine Kette anfängt zu lügen

Alle sechs haben dieselbe Bruchstelle: **eine Seite geändert, die andere nicht.** Kein Test fängt
das von allein — die Architektur-Tests prüfen Schichten und Verträge, nicht Fachwege. Was hilft,
ist die Naht mitzulesen, bevor man eine Seite anfasst.

**Zwei Quellen, eine Zählung (Kette 3/6):** Seit die Registeransicht Vorgänge und Historie aus
`RegisterZeilenBau` mischt, zählt „wie viele Zeilen zeigt das Register" nicht mehr aus einer
Tabelle. Wer nur eine Quelle ändert — ein neues Feld am Vorgang, einen neuen Filter auf
`RegisterHistorie` — und die andere vergisst, bekommt eine Zahl, die auf dem Bildschirm und im
Spiegel gleich falsch ist, weil beide aus derselben unvollständigen Funktion lesen. Kein Test
sieht das: Er prüft, dass Bildschirm und Spiegel übereinstimmen, nicht, dass beide vollständig
sind.

Kommt eine Kette hinzu oder fällt eine weg, gehört sie hier hinein — sonst steht in dieser Datei
bald dasselbe wie in einem Steckbrief, der auf Tests zeigt, die es nicht mehr gibt.
