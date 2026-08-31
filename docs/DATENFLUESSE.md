# Datenflüsse — was durch mehrere Features läuft

Die Steckbriefe (`FEATURE.md`) enden am Feature-Rand, die Fachlogik nicht. Fünf Ketten laufen
quer durch den Baum, und in keiner steht an der Nahtstelle, dass es eine gibt. Wer eine davon
ändert, ohne sie zu kennen, ändert sie an einer Stelle und lässt die anderen stehen.

Diese Datei ist **kein** Ersatz für die Steckbriefe: Sie sagt nur, welche Features zusammenhängen
und wo die Naht liegt. Was ein einzelnes Feature tut, steht weiter in seinem `FEATURE.md`.

## 1. Vom Platzhalter zum ausgefüllten Feld

Der Weg, den ein `{{Platzhalter}}` aus der Word-Vorlage bis zum fertigen Wert nimmt.

```
form_template_setup ──▶ vorgaenge ──▶ mandanten / zentralruf_reply ──▶ word_automation
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
`RegisterSpiegelService` das Sachgebiete-Register als Word- und PDF-Datei neu (§6.2).

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

```
App beenden ──▶ Sicherung im synchronisierten Ordner ──▶ App am zweiten Rechner starten
                (automation-<Rechner>.zip + arbeitsplatz-<Rechner>.json)   └──▶ Rückfrage
```

Der Anwalt arbeitet im Büro und zu Hause; die Datenbank selbst darf dabei **nicht** in den
Sync-Ordner (WAL-Modus: drei Dateien, die ein Synchronisierer einzeln und zu verschiedenen Zeiten
kopiert). Übergeben wird deshalb eine Datei (§7.2).

Beim Beenden schreibt `ArbeitsplatzDienst.StopAsync` über `AutomatischeSicherung` ein Archiv in den
eingestellten Ordner und daneben die eigene `arbeitsplatz-<Rechner>.json`. Beim Start liest
`ArbeitsplatzUebergabe` alle *fremden* Akten; ist eine davon neuer, fragt die App **vor** der
Oberfläche nach (`ArbeitsplatzUebergabeGate` → `GET api/Backup/uebergabe`), und erst auf Klick
spielt sie ein — über denselben Import wie eine Sicherung von Hand.

**Die Naht — zwei Zeitpunkte, nicht einer:** Die Akte trennt `zuletztGearbeitet` von `gesichertAm`.
Das Angebot entscheidet sich am zweiten, der Satz auf dem Bildschirm nennt den ersten. Wer beide
zusammenlegt, macht aus einem Rechner, der heute nur kurz auf war, den „neueren" Stand — obwohl sein
Archiv von vorgestern ist. Nach einer Übernahme trägt die eigene Akte deshalb *jetzt* als
Arbeitszeitpunkt und den *übernommenen* als Stand; sonst böte entweder jeder Start dasselbe Archiv
erneut an oder der andere Rechner böte den Stand postwendend zurück.

**Die zweite Naht — Übergabe ist keine Verschmelzung.** Wer übernimmt, ersetzt seinen Bestand. Was
davor schützt: die Frage selbst (sie nennt Rechner, Zeitpunkt und den eigenen Stand daneben), die
Vor-Import-Sicherung des Backends — und dass die Frage kommt, bevor irgendeine Ansicht Daten
geladen hat.

**Die dritte Naht — maschinenabhängige Pfade.** Aktenstammordner, Vorlagen-, Register- und
Sicherungsordner überleben den Import mit den Werten *dieses* Rechners
(`DatabaseBackupService.SchuetzeMaschinenPfadeAsync`). Der fremde Sicherungsordner wäre der
schlimmste: Der Rechner legte danach seine Sicherungen woanders ab, als er sein Angebot liest.

Und die Rückmeldung: Beim Beenden sieht niemand mehr zu, deshalb merkt sich jeder Lauf sein Ergebnis
lokal (`letzte-sicherung.json`, neben der Datenbank statt darin — ein Import ersetzt die Datenbank).
Der nächste Start zeigt einen Fehlschlag, der Reiter „Datensicherung" die Zeile „zuletzt gesichert".

## Wo eine Kette anfängt zu lügen

Alle fünf haben dieselbe Bruchstelle: **eine Seite geändert, die andere nicht.** Kein Test fängt
das von allein — die Architektur-Tests prüfen Schichten und Verträge, nicht Fachwege. Was hilft,
ist die Naht mitzulesen, bevor man eine Seite anfasst.

Kommt eine Kette hinzu oder fällt eine weg, gehört sie hier hinein — sonst steht in dieser Datei
bald dasselbe wie in einem Steckbrief, der auf Tests zeigt, die es nicht mehr gibt.
