# Mandanten aus einer Datei übernehmen

Im Produktivbestand liegen rund **4040 Ordner** direkt unter dem Akten-Stammordner. Sie einzeln
einem Mandanten zuzuordnen ist nicht leistbar — auch nicht mit Suche, Filtern und Massenaktion des
Zuordnungsstapels. Dieser Weg dreht die Richtung um: die Zuordnung entsteht **außerhalb** der App
dort, wo die Akten liegen, kommt als JSON-Datei herein und wird hier geprüft, gezeigt und erst nach
Freigabe geschrieben.

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

Den fertigen Arbeitsauftrag für den Erzeuger hält die App zum Kopieren bereit
(*Aus Datei übernehmen* → **Auftrag für den Erzeuger kopieren**); der Wortlaut liegt in
`Automation_App_Frontend/lib/features/mandanten/presentation/utils/import_anleitung.dart`.

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

Die Gegenstücke im Code: Backend `Features/Mandanten/Domain/Services/MandantenImport.cs`, Frontend
`Automation_App_Frontend/lib/features/mandanten/FALLSTRICKE.md`. Der HTTP-Vertrag steht wie immer in
`docs/openapi.json`.
