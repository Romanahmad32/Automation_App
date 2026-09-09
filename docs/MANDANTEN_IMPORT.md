# Mandanten aus einer Datei übernehmen

Im Produktivbestand liegen rund **4040 Ordner** direkt unter dem Akten-Stammordner. Sie einzeln
einem Mandanten zuzuordnen ist nicht leistbar — auch nicht mit Suche, Filtern und Massenaktion des
Zuordnungsstapels. Dieser Weg dreht die Richtung um: die Zuordnung entsteht **außerhalb** der App
dort, wo die Akten liegen, kommt als JSON-Datei herein und wird hier geprüft, gezeigt und erst nach
Freigabe geschrieben.

## Zwei Dateien, zwei Richtungen

Es gibt **zwei** JSON-Formate, nicht eines — und beide „gehören zum Import", laufen aber
gegenläufig. Wer das nicht vor Augen hat, liest die beiden leicht als zwei konkurrierende
Umsetzungen derselben Sache:

```
App ──(Arbeitspaket)──▶  Erzeuger/Agent  ──(Importdatei)──▶  App
```

| Datei | Richtung | Wozu |
|---|---|---|
| **Arbeitspaket** (Abschnitt „Arbeitspakete" unten) | App → Erzeuger | portioniert 4000 offene Ordner in Häppchen, die ein Agent in einer Sitzung schafft |
| **Importdatei** (Fassung 1, nächster Abschnitt) | Erzeuger → App | das Ergebnis, das tatsächlich geprüft und ins Register übernommen wird |

Die Importdatei ist die **einzige**, die zwingend nötig ist: Ein Erzeuger, der den ganzen
Stammordner selbst abarbeiten kann, liefert sie direkt, ohne je ein Arbeitspaket gesehen zu haben.
Das Arbeitspaket kommt nur dazu, wenn der Bestand zu groß für einen Durchgang ist (siehe unten) —
es ist eine Portionierungshilfe *vor* der Importdatei, kein zweiter Weg, Mandanten anzulegen.

Die drei Beteiligten:

| Wer | Was |
|---|---|
| Ein Programm auf dem Kanzleirechner | liest Ordnernamen und Schreiben, schreibt die Datei |
| Die App (Mandanten → Ordner zuordnen → *Aus Datei übernehmen*) | liest, prüft, zeigt, übernimmt |
| Der Anwalt | sieht die Vorschau an und entscheidet |

Der Haltepunkt in der Mitte ist der Zweck der Sache. Eine maschinell erzeugte Zuordnung über
viertausend Ordner ungesehen ins Register zu schreiben wäre kein Fortschritt gegenüber der
Handarbeit, sondern nur ein schnellerer Weg zu Fehlern, die hinterher niemand mehr findet.

## Das Format (Fassung 1)

```json
{
  "version": 1,
  "mandanten": [
    {
      "anrede": "herr",
      "vorname": "Mark",
      "nachname": "Schmidt",
      "strasseHausnummer": "Hauptstraße 12",
      "postleitzahl": "61348",
      "ort": "Bad Homburg",
      "emailAdresse": "",
      "telefonnummer": "",
      "notiz": "",
      "aktenOrdnernamen": ["VUnfallursache Schmidt", "Bußgeldsache Schmidt"],
      "kennzeichen": ["HG-E 1427"],
      "quelle": "VUnfallursache Schmidt/Unfall v. 12.05.2019/Schreiben.docx",
      "sicherheit": "hoch"
    }
  ],
  "ohneMandantenbezug": ["Buchhaltung 2019", "Vorlagen"]
}
```

| Feld | Bedeutung |
|---|---|
| `version` | derzeit `1`. Fehlt sie, wird 1 angenommen; jede andere wird abgelehnt statt halb gelesen |
| `vorname` / `nachname` | das Einzige, was nicht leer sein darf — zusammen sind sie der Schlüssel |
| `anrede` | `herr`, `frau` oder `keine` |
| `aktenOrdnernamen` | nur der Ordnername, kein Pfad. Mehrere je Mandant sind der Normalfall |
| `kennzeichen` | mit Bindestrich, z. B. `HG-E 1427` |
| `quelle` | frei: woher die Angaben stammen. Steht in der Vorschau an der Zeile |
| `sicherheit` | `hoch`, `mittel`, `niedrig`. Alles andere gilt als „ohne Angabe" |
| `ohneMandantenbezug` | Ordner, die keinem Mandanten gehören (Buchhaltung, Vorlagen, Ablage) |

Alle übrigen Felder dürfen leer bleiben oder fehlen. Unbekannte Felder werden übergangen — der
Erzeuger ist ein Programm, kein Formular, und eine Datei mit 4000 brauchbaren und einer krummen
Zeile darf nicht als Ganzes scheitern.

Die fertige Anleitung für den Erzeuger hält die App zum Kopieren bereit
(*Aus Datei übernehmen* → **Anleitung für den Erzeuger kopieren**); der Wortlaut liegt in
`Automation_App_Frontend/lib/features/mandanten/presentation/utils/import_anleitung.dart`.

## Arbeitspakete: die Zuordnung entsteht portionsweise

Bei rund 4040 offenen Ordnern ist selbst der beste Zuordnungsstapel keine Sitzung, sondern viele.
Ein Agent, dem man den ganzen Bestand auf einmal vorlegt, arbeitet halb oder gar nicht — die
Antwort ist deshalb nicht „kleiner denken", sondern die Arbeit in Portionen zu schneiden, die er in
einem Zug schafft.

Ein **Arbeitspaket** (`ArbeitspaketBauen.baue`) ist eine solche Portion: die nächsten N offenen
**Mandanten** samt **allen** ihren Aktenordnern, plus alles, was der Agent zum Zuordnen braucht.
Vorgabe ist N = 200, gedeckelt auf 1000 (`ArbeitspaketBauen.vorgabeAnzahl`/`hoechsteAnzahl`).

**Warum nach Mandanten geschnitten wird, nicht nach Ordnern:** Viele Mandanten haben mehrere
Aktenordner. Ein Paket, das nach Ordnern schneidet, zerreißt dieselbe Person über zwei Sitzungen —
der Agent sieht sie im zweiten Paket wieder, hält sie für neu und legt sie doppelt an. Genau das ist
die Dublette, die der Import verhindern soll. Nach Mandanten geschnitten kann sie gar nicht erst
auftreten: **ein Mandant liegt nie in zwei Paketen**, und zwischen zwei Sitzungen braucht es deshalb
keine Dublettensuche. Ordner ohne erkennbaren Namen bilden eine eigene Gruppe über ihren
Ordnernamen — sie fallen nicht unter den Tisch und ziehen auch keine fremden Ordner an sich.

### Das Dateiformat des Arbeitspakets

Eigene Fassung, unabhängig von der Importdatei — beide zählen ihre Fassungsnummer getrennt:

```json
{
  "version": 1,
  "paket": 3,
  "erstelltAm": "2026-09-05T10:12:00.000Z",
  "stammordner": "D:/Akten",
  "anleitung": "<Text aus ImportAnleitung.paketText>",
  "bekannteMandanten": [
    {
      "anzeigename": "Karl Schmidt",
      "aktenOrdnernamen": ["Strafsache Schmidt, Karl"],
      "kennzeichen": ["HG-E 1427"]
    }
  ],
  "ordner": [
    {
      "ordnername": "VUnfallursache Albrecht",
      "aktentyp": "verkehrsunfall",
      "nameVorschlagVorname": "",
      "nameVorschlagNachname": "Albrecht",
      "bekannterMandant": "Anna Albrecht",
      "begruendung": "Nachname gleich"
    }
  ]
}
```

| Feld | Bedeutung |
|---|---|
| `version` | derzeit `1`, eigene Zählung — unabhängig von der Fassung der Importdatei |
| `paket` | vom Backend vergebene Paketnummer; reist **nicht** in die Importdatei zurück |
| `stammordner` | der Akten-Stammordner, unter dem `ordner` liegen |
| `anleitung` | `ImportAnleitung.paketText` — reist mit, damit das Paket auch Tage später verständlich bleibt |
| `bekannteMandanten` | schon erfasste Mandanten (Name, Ordner, Kennzeichen), damit der Agent nicht dupliziert |
| `ordner[].aktentyp` | Name aus `Aktentyp`: `verkehrsunfall`, `bussgeld`, `straf`, `familie`, `ohnePraefix` |
| `ordner[].nameVorschlagVorname`/`nachname` | unverändert aus `nameVorschlagAusOrdner`, **nicht** nachgebessert |
| `ordner[].bekannterMandant`/`begruendung` | fehlen ganz, wenn `MandantErkennung` nichts findet |

Die Ordner stehen **nach Mandanten gebündelt und alphabetisch** in der Liste — Gruppen mit einem
Verkehrsunfall-Kandidaten zuerst, denn eine Verkehrsunfall-App braucht aus Straf-, Bußgeld- und
Familiensachen keine Stammdaten (`ArbeitspaketBauen.vergleicheGruppen`).

**Die Fassung der Importdatei selbst bleibt unverändert 1.** Das Arbeitspaket ist die Eingabe für
den Agenten, die Importdatei (oben) seine Antwort — beide Formate zählen ihre Fassung getrennt, und
die Paketnummer reist nicht mit: Welches Paket eine abgegebene Datei beendet, rechnet die App selbst
aus den Ordnernamen aus (siehe „Fortschritt" unten). Der Anwalt wird dazu nie gefragt.

## Fortschritt: die App rechnet, es wird nichts gefragt

Jedes verbuchte Paket (`POST /api/ImportPakete`) merkt sich seine Ordnernamen
(`ImportPaketEntity.OrdnernamenJson`). Ein Ordner gilt als **erledigt**, sobald er einem Mandanten
zugeordnet ist **oder** einen Vermerk „ohne Mandantenbezug" trägt — dieselbe Rechnung wie im
Zuordnungsstapel, nur andersherum. Wird ein Paket dadurch **vollständig** erledigt, setzt der
nächste erfolgreiche Import-Schreiblauf `EingelesenAm` und `Zeilen` von selbst
(`MandantenImport.FuehreAusAsync` ruft danach `SchreibeFortschrittAsync`); ein nur teilweise
abgearbeitetes Paket bleibt offen, und der Anwalt sieht am Zähler `erledigt`, wie weit es ist.

`OrdnernamenJson` ist deshalb **kein toter Ballast**, obwohl kein DTO die Liste ausliefert
(`ImportPaketDto` zeigt nur `AnzahlOrdner`/`Erledigt`): Genau darüber wird der Fortschritt
berechnet, ohne den Anwalt zu fragen, welche Datei zu welchem Paket gehört — und ein Ordner, der
später wieder frei wird, senkt die Zahl von selbst. Es gibt keinen gespeicherten Stand, der
veralten kann.

## Was die App damit macht

`POST /api/MandantenImport` prüft, `POST /api/MandantenImport?uebernehmen=true` schreibt. **Beide
Aufrufe sind derselbe Code und liefern denselben Bericht** — nur `angewendet` unterscheidet sie. Die
Vorschau kann deshalb nicht von dem abweichen, was die Übernahme tut. Ohne `uebernehmen` verändert
eine abgeschickte Datei nichts, egal woher sie kommt.

Je Zeile entscheidet der Dienst:

| Ergebnis | wann |
|---|---|
| `neu` | den Namen gibt es im Register noch nicht |
| `ergaenzt` | vorhandener Mandant, es kommen Ordner, Kennzeichen oder leere Felder dazu |
| `unveraendert` | vorhandener Mandant, die Datei bringt nichts Neues |
| `abgelehnt` | ohne Vor- und Nachnamen lässt sich kein Mandant anlegen |

Vier Regeln, die zusammen dafür sorgen, dass ein zweiter Lauf derselben Datei harmlos ist:

- **Ergänzen, nie überschreiben.** Ein leeres Feld im Register wird aus der Datei gefüllt, ein
  belegtes bleibt stehen. Weicht die Datei ab, steht das als Hinweis in der Vorschau, statt still zu
  gewinnen. Die Datei liest aus alten Schreiben — sie darf Lücken schließen, aber keine gepflegten
  Stammdaten durch eine Lesart daraus ersetzen.
- **Zwei Zeilen mit demselben Namen ergeben einen Mandanten.** Das Register weist eine Dublette mit
  409 ab; der Import darf sie nicht durch die Hintertür anlegen. Verglichen wird wie dort
  (getrimmt, kleingeschrieben).
- **Kein Ordner wird umgehängt.** Gehört er schon einem anderen Mandanten, bleibt er dort, und die
  Zeile bekommt einen Hinweis mit dessen Namen. Das gilt auch innerhalb einer Datei: beanspruchen
  zwei Zeilen denselben Ordner, bekommt ihn die erste.
- **Zuordnung sticht Vermerk.** Ein Ordner, den der Import einem Mandanten gibt, verliert ein
  vorhandenes „ohne Mandantenbezug"; steht er in beiden Listen derselben Datei, gewinnt die
  Zuordnung.

Geschrieben wird in **einer** Transaktion: entweder die ganze Datei oder nichts.

## Unbekannte Ordnernamen sperren die Übernahme

Die Datei entsteht maschinell — ein Agent kann einen Ordnernamen erfinden, verschreiben oder aus
einem Aktentext ableiten, der nie so auf der Platte stand. Deshalb werden Ordnernamen im
Bearbeiten-Dialog **ausgewählt statt getippt** (Suchfeld mit Vorschlägen aus dem gescannten
Bestand), und die Vorschau markiert jede Zeile, die einen Ordner nennt, den es im Stammordner nicht
gibt — auch in `ohneMandantenbezug`. **Solche Zeilen blockieren die Übernahme**
(`OrdnerPruefung.unbekannteZeilen`/`unbekannteOhneBezug`): `kannUebernehmen` ist falsch, solange
eine unbekannte Ordnerangabe in der Datei steht. Ein Band über der Liste sagt, wie viele Zeilen
betroffen sind, und filtert auf Klick darauf; der Anwalt berichtigt sie im Dialog oder lässt sie weg.

**Ausnahme: Liegt kein Scan vor** (leere Ordnerliste, etwa weil der Stammordner auf diesem
Arbeitsplatz nicht erreichbar ist), wird **nicht** blockiert — sonst wäre der Import auf einer
Maschine ohne Stammordner unbenutzbar. Vergleich überall case-insensitiv über `OrdnernamenMenge`.

## Zeilen berichtigen, bevor etwas geschrieben wird

Eine maschinell erzeugte Datei enthält Fehler. Ohne einen Weg, eine einzelne Zeile richtigzustellen,
bliebe nur die Wahl zwischen „den Fehler mitnehmen" und „viertausend richtige Zeilen liegen lassen" —
deshalb ist jede Zeile der Vorschau anklickbar:

- **Bearbeiten** öffnet dieselben Stammdatenfelder wie das Mandantenformular, dazu die
  Akten-Ordner der Zeile. Der Dialog zeigt oben, woher die Angaben stammen und was der Dienst an
  ihnen auszusetzen hatte.
- **Zeile weglassen** nimmt sie aus dem Vorgang — für einen Eintrag, den der Erzeuger erfunden hat.
- Geändert wird nur die Fassung im Arbeitsspeicher. **Die Datei auf der Platte bleibt unberührt**,
  und *Andere Datei* liest sie im Urzustand neu ein.

Nach jeder Änderung läuft die Prüfung erneut über die **ganze** Datei. Das ist Absicht: eine
berichtigte Zeile kann aus `abgelehnt` ein `neu` machen, einen Ordner freigeben, den vorher eine
andere Zeile beanspruchte, oder aus zwei Mandanten einen machen. Lokal nachzurechnen, was sich
dadurch ändert, wäre eine zweite Auslegung derselben Regeln — und die beiden liefen früher oder
später auseinander.

Nicht bearbeitbar sind `quelle` und `sicherheit`: sie beschreiben den Fund, nicht den Mandanten. Wer
sie überschriebe, behielte die Angaben und verlöre die Auskunft, woher sie stammen. Berichtigte
Zeilen sind in der Liste als **bearbeitet** gekennzeichnet.

## Nach dem Übernehmen

Der Bericht bleibt stehen und lässt sich weiter durchsehen — die Voreinstellung des Filters ist
„zu prüfen": abgelehnte Zeilen und alles mit Hinweis. Bei viertausend Zeilen ist eine vollständige
Liste keine Prüfung, sondern nur der Beweis, dass man nicht geprüft hat. Ab hier ist nichts mehr
änderbar; was noch falsch ist, wird im Mandantenregister berichtigt.

Was danach noch offen ist, steht wieder im Zuordnungsstapel (Mandanten → *Ordner zuordnen*) und
wird dort von Hand entschieden. Der Import soll den Stapel klein machen, nicht ersetzen.

## Sichere Treffer: ein Stapelvorschlag ohne Agent

„Sichere Treffer übernehmen" erledigt den Teil der Zuordnung, für den kein Agent nötig ist. Die
Definition ist eng und wird nicht aufgeweicht (`SichereTreffer.finde`): der Namensvorschlag aus dem
Ordnernamen liefert einen nicht leeren **Nachnamen**, `MandantErkennung.finde` liefert **genau
einen** Vorschlag, und dieser stimmt im Nachnamen nach Normalisierung **exakt** überein — im
Vornamen ebenso, **sofern** der Ordner einen liefert. Kein Tippfehler-Treffer, kein Präfix-Treffer,
kein reiner Kennzeichen-Treffer. Alles andere bleibt dem Agenten.

**Der Vorname darf fehlen**, weil die echten Aktenordner der Kanzlei keinen tragen
(`VUnfallursache <Nachname>`). „Beide exakt" wäre dort prinzipiell unerfüllbar gewesen — eine
Regel, die auf dem Produktivbestand ausnahmslos nichts findet, sieht nur streng aus. Die
Schadensrichtung bleibt gewahrt: Ohne Vornamen trägt die Eindeutigkeit allein „genau ein
Vorschlag", und der zählt auch Tippfehler-Nachbarn mit — zwei „Albrecht" im Register sind zwei
Vorschläge und damit kein sicherer Treffer.

Der Vorschlag **baut keinen neuen Weg**: Er stellt aus den sicheren Treffern eine
`MandantenImportDatei` im Arbeitsspeicher zusammen (`SichereTreffer.alsImportdatei`) und schickt sie
durch **denselben** Import wie eine Datei vom Kanzleirechner. Damit gelten unverändert Vorschau vor
dem Schreiben, „Ergänzen nie überschreiben", kein Ordner wird umgehängt, eine Transaktion, und der
Paket-Fortschritt wird mitgezogen. Die erzeugten Zeilen tragen nur Name und `aktenOrdnernamen` —
keine erfundenen Stammdaten, damit „Ergänzen nie überschreiben" nichts zu überschreiben versucht.

Die Gegenstücke im Code: Backend `Features/Mandanten/Domain/Services/MandantenImport.cs` und
`Features/Mandanten/Domain/Services/ImportPaketBuch.cs`, Frontend
`Automation_App_Frontend/lib/features/mandanten/domain/services/arbeitspaket_bauen.dart` und
`Automation_App_Frontend/lib/features/mandanten/FALLSTRICKE.md`. Der HTTP-Vertrag steht wie immer in
`docs/openapi.json`.
