# Stand der Umsetzung

Was gebaut ist und was bewusst noch fehlt. Diese Datei ist der einzige Ort für den
Umsetzungsstand — `CLAUDE.md` beschreibt Dauerregeln und veraltet deshalb nicht.
Paragraphenangaben verweisen auf [`REQUIREMENTS.md`](../REQUIREMENTS.md) im Wurzelverzeichnis.

## Umgesetzt

- **Zentralruf** — Vorbefüllung des Onlineformulars (§4.2) und Auswertung der Antwortmail
  (§4.3), dazu die ereignisbasierte Postfachüberwachung per IMAP IDLE.
- **Word-Automation** — Vorlage füllen, RVG-Berechnung, PDF-Vorschau und Prüfung in der App.
- **Mandantenregister** mit Akten/Fällen im Dateisystem (§4.6/§5.1/§6.1),
  Formularvorlagen-Verwaltung, Einstellungen.
- **Vorgang/Auftrag als eigenständige Entität** (Frontend `vorgaenge`, Backend-Slice
  `Vorgaenge`): verbindet Mandant ↔ Referenz ↔ Antwort ↔ Dokument und trägt den Lebenszyklus
  Angefragt → Beantwortet → Erstellt → Abgelegt → Versendet. „Vorgang abschließen" setzt den
  Status auf *Versendet* und zählt die laufende Auftragsnummer hoch — beides im Backend
  (`VorgangAbschlussService`), in einer Transaktion und idempotent. Eine Registertabelle gibt es
  **nicht**: die Registeransicht ist aus den abgeschlossenen Vorgängen abgeleitet.
- **Persistenz vollständig im Backend** — eingebettetes SQLite (`AutomationDbContext`,
  `%APPDATA%\AutomationService\automation.db`). Die früheren JSON-Ablagen je Feature sind weg,
  das Frontend erreicht alles über HTTP.
- **E-Mail-Versand (§4.7)** — Mail zum Vorgang in der App verfassen und über das Kanzlei-Postfach
  senden (Frontend `email_versand`, Backend-Slice `EmailVersand`, SMTP über denselben Zugang wie
  die Überwachung). Empfänger aus Mandantenregister, Zentralruf-Antwort und Versicherer-Wissensbasis
  sind anklickbar, Anrede und Betreff aus den Vorgangsdaten vorbelegt, das Anspruchsschreiben als
  PDF vorausgewählt. Geprüft wird **vor** dem Verbindungsaufbau: Fehlt ein Anhang, geht nichts
  hinaus. Erreichbar an zwei Stellen: im Speicherschritt/Abschlussdialog der Word-Automation und
  im Postfach (`MailboxVersandLeiste`, dort ohne Anhang und ohne Vorgang auch als leeres
  Anschreiben). Der Abschluss (§4.8) bleibt der eigene Schritt — das Häkchen ist nach dem Versand nur
  vorbelegt und begründet. Zweiter Weg statt Direktversand: **Entwurf in Outlook öffnen** — mit
  Empfängern, Betreff, Text und Anhängen; dort gelten Signatur und Vorlage der Kanzlei, und was
  die App nicht kennt, zieht der Anwalt in gewohnter Weise hinein. Fehlt Outlook, öffnet eine
  `.eml`; Outlook wird beim Öffnen des Dialogs im Hintergrund hochgefahren, damit der Entwurf
  nicht auf den Kaltstart wartet, und die Anhänge der dort offenen Nachricht lassen sich per Knopf
  holen. Eine **Vorschau** zeigt jederzeit, was hinausgeht.
  Die **Signatur** für den Direktversand wird einmal aus Outlook übernommen
  (Einstellungen → E-Mail-Signatur). Der **Import aus Outlook liest nur** und füllt das Formular;
  geschrieben wird beim Speichern der Seite (`signaturen/vorschau` gegen `signaturen/uebernehmen`),
  und ein Griff entfernt die Signatur ganz — Text, Formatierung und Bilder. Jedes Speichern der
  Einstellungen holt dabei zuerst den frischen Stand: Die formatierte Fassung gehört dem Dienst,
  und auf altem Stand geschrieben löschte sie sich selbst.
  Hängen an einer erfassten Postfach-Antwort Dateien, stehen
  sie beim Verfassen zum Anklicken bereit (§4.3). **Mail-Textvorlagen** sind pflegbar
  (Einstellungen → E-Mail); die gewählte ersetzt Betreff und Text, ihre `{{Platzhalter}}` füllt
  `MailVorlagenFueller` aus dem Vorgang — mit `{{Anrede}}` und `{{Zusatzgruß}}` als eigenen
  Namen und der Regel, dass eine Zeile ohne gefüllten Platzhalter ganz entfällt. Gewählt wird von
  Hand: Standardmäßig gehen Mandant und Versicherung eine gemeinsame Mail, und dort passt ein
  Mandantenanschreiben nicht hinein (§4.7/§5.3); „keine Vorlage" führt zur Vorbelegung zurück.
  Ausgangsbestand ist die Outlook-Vorlage der Kanzlei; **alle** Platzhalter eines Vorgangs stehen
  beim Schreiben einer Vorlage zur Auswahl (`PlatzhalterKatalog`, nach Gruppen, Klick setzt ein) —
  die Liste ist aus `FeldDatenquelle` abgeleitet, und ein Rundlauf-Test hält sie mit der
  Auflösung zusammen. **Anrede** und **Zusatzgruß** wählt der Anwalt je Mail aus in den
  Einstellungen gepflegten Listen (Chips über dem Betreff). Vom Zusatzgruß gilt: Er geht überall
  mit, wo die Vorlage den Platzhalter trägt; von der Anrede wird nur der **Anfang** gepflegt
  („Sehr geehrter"), in drei Beugungsformen — „Herr"/„Frau" und Nachnamen setzt der Versand dazu.
  Welche Form gilt, sagt die **Anredeart je Mail** (Chips „Herr"/„Frau"/„keine Angabe", vorbelegt
  aus `Mandant.anrede`, ohne Rückschreiben ins Register): Sie beugt die Anredezeile **und** die
  Wörter im Vorlagentext, die mit Schrägstrich geschrieben sind — `{{Mandant/Mandantin}}`,
  `{{er/sie}}`; ohne dritte Form rechnet die App die neutrale aus — gemeinsamer Wortstamm in
  Klammern („Mandant(in)"), sonst beide mit Schrägstrich („der/die"). Fehlt die Anredeart am
  Mandanten, lässt sie sich aus dem Dialog auf Klick **nachtragen**; eine hinterlegte wird von dort
  nie überschrieben (§1.3). Davon getrennt: Liest jemand mit, ist die **namentliche** Anrede
  abgewählt, aber änderbar — eine Mail an die Versicherung beginnt neutral und schreibt im Text
  trotzdem von „unserer Mandantin". **Warum** die Anrede neutral ist, steht seither darunter
  (`AnredeNeutralGrund`): sechs Lagen führen dahin, und der Empfängerkreis ist eine Auskunft, eine
  Lücke im Register eine Aufgabe. Der Umschalter „neutral anreden" wird angeboten, sobald Nachname
  und Anredeart vorliegen — nicht mehr erst, wenn die namentliche Anrede schon gilt. Ohne
  Anredebestand gilt `Anredebaustein.rueckfall`, und der folgt der Anredeart wie jeder gespeicherte
  Anfang; lässt sich der Bestand nicht laden oder ist er leer, sagt die App das statt die Auswahl
  zu verstecken — gelöscht ist die Liste, nicht die Anredezeile. Fehlt der **Nachname** (Vorgang
  ohne Mandanten im Register), steht die gewählte Anredeart allein da („Sehr geehrter Herr")
  statt auf „Damen und Herren" zurückzufallen; zurück führt „Keine Angabe".
  Über der Anredeart steht, worauf sie **jetzt** wirkt (`AnredeartWirkung`) — Anredezeile,
  gebeugte Wörter der Vorlage, beides oder nichts; ein fester Satz behauptete vorher immer beides.
  Fehlt der Vorlage die Stelle für die Anrede (`{{Anrede}}`), steht das dabei, und Grund wie
  Umschalter entfallen: Wo keine Zeile ist, gibt es nichts zu erklären.
  Der **Vorlageneditor** sagt beim Schreiben, welche Platzhalter
  nichts liefern werden (`VorlagenPruefung`, Hinweis ohne Riegel) und was die Beugungen in allen
  drei Formen ergeben — eine errechnete neutrale Form ist als solche markiert. Hat der Anwalt den
  Text selbst angefasst, tauschen Anrede und Zusatzgruß darin weiter ihre Stelle (`TextNachtrag`);
  Vorlage und Anredeart nicht mehr — das sagt ein Hinweis, samt Knopf „Text neu erzeugen"; die
  Merker dafür setzt schon `starte` und zieht jede Ableitung nach, sonst lief der Tausch leer.
  Ein **Vorgangswechsel** nimmt Gruß, Anredeart und die Entscheidung „neutral anreden" zurück und
  behält, was der Anwalt selbst eingetragen hat — auch eine Adresse, die der neue Vorgang zufällig
  ebenfalls vorschlägt.
  Der **Vorgang** ist im Dialog wählbar (`VorgangAuswahl`, durchsuchbar), damit auch ein
  Entwurf aus dem Postfach ohne Treffer nachträglich vorbelegt werden kann. Was leer blieb, steht
  **offen** im Formular — mit Stelle, Folge und Grund („im Mandantenregister nicht erfasst",
  „kein Feld dieses Namens") —, und ein Dialog stellt Vorlage und Ergebnis zeilenweise gegenüber.
- **Sicherung** — das `backup`-Feature schreibt Datenbank und Vorlagen als ZIP
  (§7.2, `SicherungsArchiv`; Begründung in `docs/RELEASE.md`). Ist eine **Sicherungsablage**
  eigens gewählt oder aus dem App-Daten-Ordner abgeleitet (`SicherungsAblageVorgabe`, #103; ohne
  beides bleibt sie abgeschaltet — gedacht: ein OneDrive-Ordner), sichert die App zusätzlich beim
  Beenden und nach jedem Vorgangsabschluss von selbst dorthin — und der **zweite Arbeitsplatz**
  bietet diesen Stand beim Öffnen zur Übernahme an, nach Rückfrage und mit sichtbarem Vergleich
  beider Stände. Die Kette steht in `docs/DATENFLUESSE.md`. **Bewusst nicht gebaut:** ein
  Zusammenführen zweier gleichzeitig bearbeiteter Stände — übergeben wird eine Datei, nicht
  verschmolzen.
- **Ein Ordner für alle App-Daten, relative OneDrive-Pfade (#103)** — statt vier Ordner einzeln zu
  wählen, legt der Anwalt einen **App-Daten-Ordner** fest (Vorschlag: ein erkannter
  OneDrive-Ordner, `SynchronisierterWurzelOrdner`); Vorlagen-, Register- und Sicherungsablage
  leiten sich daraus ab (`AppDatenOrdnerVorgabe`, `VorlagenOrdnerVorgabe`, `RegisterAblageVorgabe`,
  `SicherungsAblageVorgabe`) und lassen sich weiterhin einzeln abweichend einstellen. Liegt ein
  gewählter Ordner unter dem erkannten OneDrive-Wurzelordner, speichert das Backend ihn **relativ
  mit festgehaltenem Anker** (`%OneDriveCommercial%\…`, `AppOrdnerPfad`) statt absolut — damit er
  bei der Übernahme (#39) mit dem zweiten Arbeitsplatz mitkommt, während ein Ordner außerhalb
  absolut und maschinengebunden bleibt. `GET /api/Settings/ordner` liefert je Ordner einen
  sprechenden Zustand (nicht gesetzt/abgeleitet/Standard/bereit/Ordner fehlt/Anker fehlt) statt
  eines Pfads ins Leere. Bestand mit vier absolut gesetzten Ordnern läuft nach der Migration
  unverändert weiter, nichts wird verschoben.
- **Postfachantworten** liegen in derselben Datenbank (`DbReceivedReplyStore`, Tabelle
  `ReceivedReplies`). Jeder Treffer wird nach bestem Wissen über die Referenz einem Vorgang
  zugeordnet (`VorgangId`/`Zugeordnet`), **ohne** den Vorgang zu verändern — die Übernahme
  bleibt der bestätigte Schritt im Frontend.
- **Word-Export des Sachgebiete-/Auftragsregisters (§6.2)** — die App ist das führende Register
  und schreibt ihren Stand als frische Word- **und** PDF-Tabelle in einen Ordner aus den
  Einstellungen — eigens gewählt oder aus dem App-Daten-Ordner abgeleitet (`RegisterSpiegelService`,
  `RegisterAblageVorgabe`, #103, `POST api/Vorgaenge/register/export`, `GET …/register/stand`);
  die Kette steht in `docs/DATENFLUESSE.md`.
- **Einheitliche Rückmeldungen (Issue #56, 04.09.2026)** — Baustein `Rueckmeldung` zeigt Erfolgs-,
  Hinweis- und Fehlermeldungen oben rechts als Stapel über der Dialogbarriere (Erfolg 3 s, Hinweis
  5 s, Fehler bis zum Schließen). Alle 52 Snackbar-Stellen umgestellt, ein Architekturtest wacht.

### Intelligente Datenwiederverwendung (Punkte 1–7 des Verbesserungsplans)

- Assistenten-Eingaben und Schadensaufstellung bleiben am Vorgang (`feldWerte`,
  `schadensaufstellung`) und werden beim Wiedereinstieg als Vorbelegung angeboten; sie
  gewinnen gegen die Heuristiken. Ausdrücklich gebundene Felder fließen in die
  Vorgangsfelder zurück (`VorgangRueckfluss`).
- Ohne gespeicherten Stand startet die Schadensaufstellung mit den Standardpositionen (§4.4):
  ab Werk die fünf üblichen (`StandardSchadenspositionen`), vorbelegt in der Bezeichnung und leer
  im Betrag; das „+"-Menü holt eine gelöschte davon zurück. Positionen ohne Betrag fallen beim
  Übernehmen heraus. Bezeichnungen **und** Beträge sind im Einstellungs-Reiter
  „Schadensaufstellung" konfigurierbar (mit Tabellen-Vorschau, `StandardpositionenEditor`);
  gespeichert im Backend (`GET`/`PUT api/Settings/schadenspositionen`, leere Liste = Vorgabe).
  Die Titelzeilen-Farbe der Tabelle liegt im selben Reiter, speichert sofort beim Auswählen und
  färbt die Vorschau live.
- `MandantErkennung` schlägt beim Tippen passende Registereinträge vor (Kennzeichen,
  Nachname, „Meinten Sie …?"-Banner) — ein Vorschlag, die Übernahme bleibt ein Klick.
- Der **Zuordnungsstapel** (eigene Seite unter Mandanten) ist auf den Produktivbestand von rund
  4000 Akten-Ordnern ausgelegt: flacher Scan mit Nachladen der Fälle, `ListView.builder`, Suche,
  Zeitfenster und drei Töpfe (Verkehrsunfall / andere Sachgebiete / „ohne Mandantenbezug").
  Der dritte ist ein gespeicherter Status (`OrdnerStatus`, `api/OrdnerStatus`), einzeln oder als
  Massenaktion setzbar und jederzeit zurücknehmbar — kein Löschen und kein Ausblenden.
- Weil viertausend Ordner auch gefiltert viertausend Entscheidungen bleiben, kann die Zuordnung
  **von außen kommen**: ein Programm auf dem Kanzleirechner liest Ordner und Schreiben und schreibt
  eine JSON-Datei, die App prüft sie und zeigt das Ergebnis, bevor etwas geschrieben wird; einzelne
  Zeilen lassen sich in der Vorschau berichtigen oder weglassen
  (`POST /api/MandantenImport`, Format in [`docs/MANDANTEN_IMPORT.md`](MANDANTEN_IMPORT.md)).
  Vorschau und Übernahme sind derselbe Aufruf; ergänzt wird nur, überschrieben nie, und ein zweiter
  Lauf derselben Datei ändert nichts. Der Auftrag für den Erzeuger der Datei ist in der App
  kopierbar.
- Der Backend-Slice `Versicherer` lernt Kontaktdaten aus jeder Antwort und füllt damit
  Lücken in `missingFields`, mit Herkunftshinweis.
- Zuordnung Antwort → Vorgang fällt notfalls auf Gegner-Kennzeichen + Unfalldatum zurück
  (`ZuordnungVermutet`, muss bestätigt werden). Widersprechende Werte aus der Antwort
  (Gegner, Unfalldatum) erscheinen als Behalten/Überschreiben-Entscheidung
  (`AntwortKonflikte` + Dialog), statt still verworfen zu werden.
- `VorgangVollstaendigkeit` zeigt auf der Vorgangskachel, was dem Anspruchsschreiben noch
  fehlt; vorbelegte Assistentenfelder nennen je Feld ihre Herkunft (`PrefillWert`).

## Noch nicht gebaut

- **Bestätigung vor dem Hochzählen (§7.1)** — die Auftragsnummer wird nach dem Abschluss immer
  automatisch erhöht. Die geforderte Einstellung „automatisch oder erst nach Bestätigung" gibt es
  weder in `KanzleiSettings` noch im Backend.
