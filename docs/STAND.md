# Stand der Umsetzung

Was gebaut ist und was bewusst noch fehlt. Diese Datei ist der einzige Ort für den
Umsetzungsstand — `CLAUDE.md` beschreibt Dauerregeln und veraltet deshalb nicht.
Paragraphenangaben verweisen auf `REQUIREMENTS.md` (nicht versioniert, siehe `CLAUDE.md`).

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

- **E-Mail-Versand (§4.7)** — „Vorgang abschließen" markiert nur als erledigt und zählt hoch.
  Der Versand bleibt Handarbeit, die Empfängerlogik aus §4.7 ist nicht verdrahtet.
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
