# mandanten — Fallstricke

Der lange Rest zu `FEATURE.md`. Der Steckbrief hat ein Zeilenbudget, diese Datei nicht: was hier
steht, musste nicht in vierzig Zeilen passen. Die Punkte, die man **vor** dem ersten Griff in das
Feature kennen muss, stehen weiter im Steckbrief — hier steht, was einen beim zweiten erwischt.

## Zuordnungsstapel: alles hängt an der Größenordnung

Im Produktivbestand der Kanzlei liegen rund **4040 Ordner** direkt unter dem Akten-Stammordner. Jede
Entscheidung in diesem Bereich folgt daraus, und wer sie zurückdreht, macht die Seite wieder
unbedienbar:

- **Der Scan ist flach.** `FilesystemAktenDatasource.scanAkten` liest nur die erste Ebene, plus ein
  `stat` je Ordner für `Akte.geaendertAm` (das trägt den Filter „geändert seit …"). Die Fälle holt
  `scanFaelle` je Akte nach — ausgelöst beim Aufklappen einer `MandantCard` bzw. beim Wählen eines
  Ordners im Ablage-Formular. `Akte.faelleGeladen` unterscheidet „noch nicht gelesen" von „gelesen,
  es gibt keine"; ohne diese Unterscheidung stünde überall „0 Fälle".
- **Kein Rescan nach einer Änderung am Register.** `MandantenOverviewBloc` schreibt den Zustand fort:
  Zuordnen tauscht den Mandanten in der Liste, Löschen nimmt ihn heraus, und die betroffenen Ordner
  wechseln dadurch von selbst die Seite. Wer wirklich nur das Register braucht (neuer oder
  bearbeiteter Mandant), nimmt `LoadMandantenUebersichtEvent(nurRegister: true)`.
- **Kein Spinner statt der Liste.** Ein Neuladen setzt `neuLadend` und lässt den bisherigen Stand
  stehen (`MandantenZustandsBereich` zeigt dafür einen Fortschrittsbalken). Ein
  `MandantenOverviewLoading` mittendrin verwürfe Scrollstand und Filter.
- **Nur `ListView.builder`.** Weder der Stapel noch die Mandantenliste noch die Liste im
  `ZuordnenDialog` darf über eine `Column` oder ein `ListView(children: [...])` laufen — die bauen
  alle Kinder auf einmal.
- **Die Mandantenliste kommt seitenweise** — `GET /api/Mandanten/seite`, 50 je Abruf, nachgeladen
  beim Weiterscrollen. `MandantenOverviewLoaded.mandanten` ist damit **ein Ausschnitt** und nicht
  mehr der Bestand. Daran hängen zwei Dinge, die man leicht übersieht:
  - Die **Suche** läuft im Dienst über Name, Ort und Ordnernamen des ganzen Bestands. Im Speicher zu
    filtern fände nur, was gerade geladen ist — je nach Scrollstand mal den gesuchten Mandanten und
    mal nicht.
  - **Was den ganzen Bestand braucht, holt ihn ausdrücklich.** Der Zuordnungsstapel trennt die
    gescannten Ordner an `GET /api/Mandanten/aktenordner` (alle zugeordneten Ordnernamen) statt an
    `mandanten`, und der `ZuordnenDialog` sucht über einen eigenen `MandantenSucheCubit`. Beides aus
    der geladenen Seite abzuleiten sähe richtig aus und wäre es nur, solange das Register kurz ist.
- Fehlt der Stammordner, liefert `getAkten()` eine leere Liste statt eines Fehlers, und der Bloc
  verwirft ein `Left` des Scans still — leer ist Absicht, kein Fehlerschlucken. Für den Abruf der
  zugeordneten Ordner gilt das **nicht**: ohne ihn stünden zugeordnete Ordner als offen im Stapel,
  deshalb ist sein Fehlschlag beim Erstladen ein Fehler.
- **Eine gescheiterte Einzelaktion kostet keine Seite.** Zuordnen, Löschen und der Vermerk setzen
  `MandantenOverviewLoaded.fehler` und lassen den Stand stehen; `MandantenOverviewError` bleibt dem
  Fall vorbehalten, in dem das Laden selbst fehlgeschlagen ist. Sonst kostete eine
  fehlgeschlagene Massenaktion den Scan über tausende Ordner, den Filter und den Scrollstand — mehr,
  als die Aktion wert war.

## Ordnernamen: eine Schreibweise, ein Ordner

Der Ordnername ist der fachliche Schlüssel — für die Zuordnung am Mandanten **und** für den Vermerk.
Er kommt aus dem Windows-Dateisystem, und dort sind „VUnfallursache Mark" und „Vunfallursache Mark"
derselbe Ordner; zwei solche nebeneinander gibt es gar nicht. Verglichen wird er deshalb überall
**ohne Rücksicht auf Groß- und Kleinschreibung**:

| Wo | Wie |
|---|---|
| Frontend (Stapel, Filter, Zuordnung) | `OrdnernamenMenge` — die eine Menge mit `enthaelt` |
| Backend, in C# | `StringComparer.OrdinalIgnoreCase` (`OrdnerStatusRegister`, `MandantenImportLauf`) |
| Backend, in SQLite | Kollation `NOCASE` auf `OrdnerStatus.Ordnername`; der Unique-Index erbt sie |

Der Import ist der Grund, warum das zählt: Seine Datei entsteht maschinell aus Aktentexten, und ihre
Schreibweise weicht von der auf der Platte ab. Genau verglichen fiele der zugeordnete Ordner im
Stapel nie weg, die Mandantenkarte zeigte keine Akte — und der Bericht meldete trotzdem
„1 Ordner zugeordnet". Schlimmer noch beim Vermerk: Griffe die Rücknahme über die abweichende
Schreibweise daneben, wäre ein Ordner einem Mandanten zugeordnet **und** als „ohne Mandantenbezug"
vermerkt. Wer hier eine Stelle auf genauen Vergleich zurückdreht, bekommt genau das zurück.

## Ordner ohne Mandantenbezug — drei Zustände statt zwei

Nicht jeder Ordner unter dem Stammordner gehört zu einem Mandanten. Ein Ordner hat deshalb drei
Zustände, und `ZuordnungFilter.ansichtVon` teilt genau danach in die drei Ansichten auf:

| Zustand | woran er hängt | Ansicht |
|---|---|---|
| zugeordnet | `Mandant.aktenOrdnernamen` | gar nicht im Stapel |
| offen, Verkehrsunfall-Kandidat | Aktentyp-Präfix (Heuristik) | „Verkehrsunfall" — der Arbeitsvorrat |
| offen, anderes Sachgebiet | Aktentyp-Präfix (Heuristik) | „Andere Ordner" |
| ohne Mandantenbezug | `OrdnerStatus` in der Datenbank | „Ohne Mandantenbezug" |

Drei Dinge daran sind Absicht und keine Feinheit:

- **Der Vermerk sticht die Heuristik.** Steht ein Ordner in `OrdnerStatus`, zählt sein Präfix nicht
  mehr — die ausdrückliche Entscheidung des Anwalts geht vor der Namensraterei.
- **Ein Ordner ohne erkanntes Präfix bleibt im Arbeitsvorrat.** „Max Mustermann" kann sehr wohl eine
  Verkehrsunfallsache sein. Die Heuristik darf Arbeit ersparen, aber nichts verschlucken.
- **Vermerken ist kein Löschen.** Es wird nichts entfernt und kein Ordner angefasst; jeder Vermerk
  ist einzeln oder als Massenaktion zurücknehmbar. Nur deshalb darf der Stapel überhaupt
  standardmäßig etwas ausblenden — und nur deshalb kann er auf null gehen
  (`MandantenOverviewLoaded.offeneOrdnerAnzahl`).

Der Weg über HTTP ist bewusst schmal: `GET /api/OrdnerStatus` liest, `PUT /api/OrdnerStatus` setzt.
Beide arbeiten auf einer **Liste** von Ordnernamen, `status: null` nimmt zurück, und die Antwort ist
jedes Mal der vollständige Stand danach. So bleibt die Massenaktion über hunderte Ordner ein Aufruf
und ein Zustandswechsel — statt hunderter Aufrufe und eines Rescans.

`OrdnerStatusArten` kennt heute genau einen Wert. Die Tabelle trägt trotzdem eine Statusspalte statt
bloßer Zeilen, weil daneben absehbar weitere Entscheidungen stehen (Sammelordner, Ablage). Kommt
eine dazu: Wert in `OrdnerStatusArten` **und** in `OrdnerStatusArt` (Dart) ergänzen — ein dem
Frontend unbekannter Status fällt sonst auf `ohneMandantenbezug` zurück, damit eine ältere
Oberfläche den Vermerk nicht verliert und der Ordner still in den Stapel zurückfällt.

Offen bleibt aus Paket 3 von Issue #19: Namensvorschlag je Zeile statt Dialog und Mehrfachauswahl.
`nameVorschlagAusOrdner` und `MandantErkennung` liegen dafür bereit und sind auf dieser Seite nur
noch nicht zusammengeschaltet.

## Import: die Zuordnung kommt von außen

Suche, Filter und Massenaktion machen den Stapel bedienbar, aber nicht kurz: viertausend Ordner
bleiben viertausend Entscheidungen. Der Import dreht die Richtung um — die Zuordnung entsteht dort,
wo die Akten liegen, und kommt als Datei herein. **Das Format steht in
`docs/MANDANTEN_IMPORT.md`**, hier stehen die Fallen.

- **Vorschau und Übernahme sind derselbe Aufruf.** `POST /api/MandantenImport` prüft,
  `?uebernehmen=true` schreibt; der Bericht ist beide Male derselbe Typ mit demselben Inhalt, nur
  `angewendet` unterscheidet sie. Wer daraus zwei Wege macht, bekommt eine Vorschau, die etwas
  anderes zeigt als die Übernahme tut — und niemand merkt es, weil beide für sich plausibel sind.
  Aus demselben Grund ist die schreibende Betriebsart nicht die voreingestellte: ohne
  `uebernehmen=true` kann eine abgeschickte Datei nichts verändern.
- **Ergänzen, nie überschreiben** (`MandantImportAbgleich`). Ein leeres Feld wird gefüllt, ein
  belegtes bleibt stehen, eine Abweichung wird zum Hinweis. Nur deshalb ist ein zweiter Lauf
  derselben Datei harmlos — und der zweite Lauf ist der Normalfall, weil der Erzeuger nachbessert.
- **Der Import geht nicht über `MandantenRepository.CreateAsync`.** Das wäre bei viertausend Zeilen
  viertausend `SaveChanges` und viertausend Dublettenprüfungen über den ganzen Bestand.
  `MandantenImportLauf` hält die beiden Verzeichnisse (Name → Mandant, Ordner → Besitzer) selbst und
  lässt sie mitwachsen; daran hängen zwei Eigenschaften, die eine Maschinendatei braucht: zwei
  Zeilen mit demselben Namen ergeben einen Mandanten, und zwei Zeilen können nicht denselben Ordner
  bekommen. Die Namensregel dafür ist `MandantName.Normalisiere` — **dieselbe**, mit der das
  Register die 409-Dublette erkennt. Eine zweite Fassung liefe beim ersten Sonderfall auseinander,
  und der Import legte an, was das Register abgelehnt hätte.
- **Zuordnung sticht Vermerk**, in beide Richtungen: ein zugeordneter Ordner verliert sein „ohne
  Mandantenbezug", und ein Ordner in beiden Listen derselben Datei wird zugeordnet, nicht vermerkt.
  Sonst stünde in der Datenbank, ein Ordner gehöre einem Mandanten und zugleich keinem.
- **Der Bericht zählt nur, was der Lauf wirklich ändert.** Ein Ordner, der den Vermerk schon trägt,
  zählt nicht noch einmal als „ohne Mandantenbezug" — der Lauf kennt dafür den Ausgangsstand der
  Vermerke. Und die **Vorschau nennt keine Mandanten-IDs**: Schlüssel vergibt die Datenbank, eine
  vorweggenommene Nummer wäre eine Zusage, die der Bericht nicht halten kann.
- **Ein Widerspruch innerhalb der Datei nennt nicht das Register.** Steht derselbe Mandant zweimal
  darin, lautet der Hinweis „frühere Zeile" — das Register kennt ihn ja noch gar nicht.
- **Die Voreinstellung des Berichtsfilters ist „zu prüfen", nicht „alle."** Bei viertausend Zeilen
  ist eine vollständige Liste keine Prüfung, sondern nur der Beweis, dass man nicht geprüft hat.
- **Jede Zeile ist in der Vorschau noch änderbar** (`ImportEintragDialog`), und jede Änderung löst
  eine neue Prüfung der **ganzen** Datei aus. Das ist kein Aufwand, den man sparen sollte: eine
  berichtigte Zeile kann einen Ordner freigeben, den vorher eine andere beanspruchte, oder aus zwei
  Mandanten einen machen. Wer die Folgen lokal nachrechnete, hätte eine zweite Auslegung derselben
  Regeln. Die geänderte Datei wird dabei erst zum Zustand, wenn ihr Bericht da ist — sonst zeigte
  die Liste einen Augenblick lang Zeilennummern des alten Berichts über den Einträgen der neuen
  Datei, und der nächste Klick träfe die falsche Zeile.
- `ImportMandantEintrag.bearbeitet` hängt **am Eintrag**, nicht an einer Zeilennummer daneben:
  Zeilen verschieben sich, sobald eine weggelassen wird. Das Feld geht bewusst nicht über die
  Leitung (`toJson` kennt es nicht) — es gilt dem laufenden Vorgang, nicht dem Bestand, und stünde
  sonst im Vertrag, ohne dass das Backend etwas damit anfinge.
- Der Auftrag für den Erzeuger der Datei liegt als Text in `presentation/utils/import_anleitung.dart`
  und ist in der App kopierbar. Er beschreibt dasselbe Format wie die Doku — ändert sich das Format,
  ändern sich **beide**.

## Ablage

- `legeDokumentAb` schreibt an zwei Stellen: erst die Dateikopie ins Dateisystem, danach
  `PUT /api/Mandanten/{id}` für den Ordner am Mandanten (nur wenn wirklich abgelegt wurde). Wer an
  der Ablage arbeitet, muss beide Seiten zusammenhalten.
- Die Ablage-Oberfläche liegt nicht hier, sondern in `word_automation` (`akten_ablage_section.dart`) —
  hier liegen nur `AblageCubit` und UseCase; auch Formatwahl und Fall-Ordnername entstehen dort.
- Eine Ablage umfasst **alle Fassungen eines Schreibens** (Word, PDF oder beide) und gelingt oder
  scheitert als Ganzes: `quelldateiPfade` hinein, `zielpfade` heraus. Einzeln entschieden liefen die
  Namen auseinander.
- Liegt im Fall-Ordner schon eine gleichnamige Datei, **schreibt die Ablage nichts**, sondern meldet
  die vorhandenen zurück: `AblageErgebnis.konfliktMit` → `AblageStatus.konflikt`; der Cubit merkt
  sich die offene Anfrage, die Oberfläche fragt **einmal** und ruft `konfliktLoesen` bzw.
  `konfliktAbbrechen`. „Beide behalten" nummeriert alle Fassungen gemeinsam. Sonst ersetzt
  `File.copy` die Akte still.

## Register

Gleicher Vor- und Nachname ergibt beim Anlegen/Ändern ein 409 des Backends, das als
`MandantException` ankommt. `MandantErkennung` bleibt davon unabhängig reiner Vorschlag — die
Übernahme ist ein Klick.

`AktentypErkennung.praefixe` ist die **einzige** Präfixtabelle: der Filter liest sie, und
`nameVorschlagAusOrdner` streift damit dasselbe Präfix für den Namensvorschlag ab. Zwei Listen wären
beim nächsten gefundenen Schreibfehler auseinandergelaufen. Die Schreibweisen sind die in der Kanzlei
beobachteten, uneinheitlichen; eine unbekannte kostet nichts, sie landet nur unter „ohne Präfix".

## Kennzeichen am Mandanten: aufgenommen wird die Konvention

`KennzeichenEditor` prüft mit `istKennzeichen` und zeigt `KennzeichenField.hinweis` — dieselbe
Auffassung davon, was ein Kennzeichen ist, wie jedes Eingabefeld der App. Aufgenommen wird der
**normalisierte** Wert: `TexteListenEditor.normalisiere` läuft vor Prüfung, Dublettenvergleich und
Aufnahme.

Diese Reihenfolge ist der Zweck. Ohne sie stünde derselbe Wagen zweimal in der Liste — einmal als
`HG-E 1427`, einmal als `hge1427` — und die Auswahlhilfe im Ausfüllschritt böte ihn zweimal an,
obwohl der Vergleich (`gleichesKennzeichen`) beide längst für gleich hält.
