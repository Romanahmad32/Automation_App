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
  (Einstellungen → E-Mail-Signatur). Hängen an einer erfassten Postfach-Antwort Dateien, stehen
  sie beim Verfassen zum Anklicken bereit (§4.3). **Noch offen:** die pflegbaren
  Mail-Textvorlagen je Empfängertyp
  (§4.7/§5.3); dafür ist `EmailEntwurfErzeuger` die vorgesehene Stelle.
- **Sicherung** — das `backup`-Feature schreibt Datenbank und Vorlagen als ZIP
  (§7.2, `SicherungsArchiv`; Begründung in `docs/RELEASE.md`).
- **Postfachantworten** liegen in derselben Datenbank (`DbReceivedReplyStore`, Tabelle
  `ReceivedReplies`). Jeder Treffer wird nach bestem Wissen über die Referenz einem Vorgang
  zugeordnet (`VorgangId`/`Zugeordnet`), **ohne** den Vorgang zu verändern — die Übernahme
  bleibt der bestätigte Schritt im Frontend.

### Intelligente Datenwiederverwendung (Punkte 1–7 des Verbesserungsplans)

- Assistenten-Eingaben und Schadensaufstellung bleiben am Vorgang (`feldWerte`,
  `schadensaufstellung`) und werden beim Wiedereinstieg als Vorbelegung angeboten; sie
  gewinnen gegen die Heuristiken. Ausdrücklich gebundene Felder fließen in die
  Vorgangsfelder zurück (`VorgangRueckfluss`).
- `MandantErkennung` schlägt beim Tippen passende Registereinträge vor (Kennzeichen,
  Nachname, „Meinten Sie …?"-Banner) — ein Vorschlag, die Übernahme bleibt ein Klick.
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
- **Word-Export des Sachgebiete-/Auftragsregisters (§6.2)** — die In-App-Ansicht gibt es im
  genauen Spaltenschema (laufende Nr | Aktenzeichen Abteilung | Name ./. Gegner + Sachbestand
  v. Datum | Rechtsgebiet), der Export steht hinter einem Platzhalter
  (`NichtVerfuegbarerRegisterWordExporter`, `verfuegbar == false`).

  **Die Anforderung hat sich geändert:** nach §6.2 ist inzwischen die App das führende
  Register und exportiert dasselbe Spaltenschema als frische Word-/PDF-Tabelle. Sie muss
  **nicht** mehr in das bestehende mehrseitige Dokument der Kanzlei anhängen — der Platzhalter
  wartet also nicht länger darauf, dass diese Vorlage beschafft wird.
