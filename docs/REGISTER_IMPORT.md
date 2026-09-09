# Registerhistorie aus einer Datei übernehmen

Das Register der Kanzlei vor der Umstellung auf die App liegt in einem Word-Dokument mit rund
**90 Seiten** und Tausenden Zeilen — laufende Nummern je Jahr durchgehend, seit dem ersten
Jahrgang des Registers (im vorliegenden Bestand 2018). Ein festes Startjahr kennt die App nicht:
Welcher Jahrgang der erste ist, ergibt sich aus dem übernommenen Bestand, nicht aus einer Vorgabe.

Das ganze Dokument auf einmal einzulesen ist weder für einen Agenten noch für den Anwalt eine
Sitzung: Der **Jahrgang** ist die Einheit, in der übernommen und geprüft wird, rund 200 Zeilen je
Jahr. Die **laufende Nummer** ist dabei die Vollständigkeitsprobe — sie läuft je Jahrgang
lückenlos von 01 aufwärts; fehlt eine Nummer, ist eine Zeile verloren gegangen, die sonst niemand
bemerkt (§6.2).

Die drei Beteiligten:

| Wer | Was |
|---|---|
| Ein Programm auf dem Kanzleirechner (oder ein Agent) | liest einen Jahrgang aus der Vorlage, schreibt die Datei |
| Die App (Register → *Historie* → *Datei einlesen…*) | liest, prüft je Jahrgang, zeigt, übernimmt |
| Der Anwalt | wählt den Jahrgang für den Erzeuger, sieht die Vorschau je Jahrgang an und entscheidet |

Der Haltepunkt in der Mitte ist der Zweck der Sache: Der Altbestand hat Tippfehler und
Widersprüche (eine Abteilung, deren Sachbestandstext ein anderes Rechtsgebiet nennt, eine
Abteilung mal `C 03o` mal `C03o` geschrieben, eine Nummer mit Zusatz `10/19-I`). Ein Erzeuger, der
das still glättet, verliert die Information; einer, der es still übernimmt, baut die Fehler
unverändert ins neue Register ein. Die App übernimmt Widersprüche deshalb **wie sie in der
Vorlage stehen** und markiert sie als Befund — die Bereinigung ist Sache des Anwalts, in der App,
nicht Sache des Erzeugers.

## Das Format (Fassung 1)

Eine Datei trägt einen oder mehrere Jahrgänge:

```json
{
  "version": 1,
  "jahrgaenge": [
    {
      "jahrgang": 2019,
      "zeilen": [
        {
          "laufendeNummer": 10,
          "nummerZusatz": "-I",
          "spalte1": "10",
          "aktenzeichen": "10/19-I",
          "abteilung": "C02",
          "abteilungRoh": "C 02",
          "sachart": "",
          "mandant": "Bernd Mustermann",
          "gegner": "Beate Mustermann",
          "sachbestand": "Ehescheidung",
          "unfalldatum": "",
          "rechtsgebiet": "Familienrecht",
          "freitext": "10/19-I C 02 Bernd Mustermann ./. Beate Mustermann  Ehescheidung",
          "sicherheit": "niedrig",
          "hinweise": ["Nummer trägt den Zusatz -I", "Sachbestand ohne Datum"]
        }
      ]
    }
  ]
}
```

Enthält die Datei nur **einen** Jahrgang, genügt die Kurzform: `jahrgang` und `zeilen` stehen dann
direkt auf oberster Ebene, statt in `jahrgaenge` verschachtelt zu sein.

| Feld | Bedeutung |
|---|---|
| `version` | derzeit `1`. Fehlt sie, wird 1 angenommen; jede andere wird abgelehnt statt halb gelesen |
| `jahrgang` | die vierstellige Jahreszahl der Gruppe (z. B. `2019`) |
| `laufendeNummer` | die Nummer aus Spalte 2 der Vorlage — die Vollständigkeitsprobe je Jahrgang |
| `nummerZusatz` | ein Zusatz zur Nummer, wortgetreu wie in der Vorlage (z. B. `-I` bei `10/19-I`) |
| `spalte1` | die Nummer wortgetreu wie in Spalte 1 der Vorlage — Beleg, gegen den `laufendeNummer` und die Nummer im Aktenzeichen geprüft werden |
| `aktenzeichen` | das vollständige Aktenzeichen aus der Freitextzelle (z. B. `10/19-I`) |
| `abteilung` | die Abteilung normalisiert (`C 02` → `C02`), wie im Sachgebietskatalog (§7.1) |
| `abteilungRoh` | die Abteilung wortgetreu wie in der Vorlage — Beleg, falls die Normalisierung danebengeht |
| `sachart` | die Sachart aus Form B (z. B. „Bußgeldsache", „Strafsache"), leer bei Form A |
| `mandant` | der Name der Partei vor „./." bzw. hinter der Sachart |
| `gegner` | der Name der Partei hinter „./." — leer bei Form B |
| `sachbestand` | der Sachverhalt aus der Freitextzelle (z. B. „Ehescheidung", „Unfallflucht") |
| `unfalldatum` | das Datum „v. …" aus der Freitextzelle, wortgetreu — leer, wenn keins genannt ist |
| `rechtsgebiet` | das Rechtsgebiet aus Spalte 3 der Vorlage, wortgetreu |
| `freitext` | die vollständige Freitextzelle unverändert — Beleg für alles, was aus ihr herausgelesen wurde |
| `sicherheit` | `hoch`, `mittel` oder `niedrig`; alles andere gilt als „ohne Angabe" (zählt wie `niedrig`) |
| `hinweise` | kurze Klartextsätze zu Auffälligkeiten dieser Zeile, wortgetreu formuliert, nicht geraten |

Alle Felder sind nullable; fehlt eines, wird es beim Einlesen zu einer leeren Zeichenkette.

### Sicherheitsstufen

Der Erzeuger schätzt jede Zeile ehrlich ein, statt zu glätten oder zu raten:

- **hoch** — vollständige Form A (`Name ./. Gegner  Sachbestand v. Datum`), nichts fehlt.
- **mittel** — Form B (`Sachart Name  Sachbestand`), eine fehlende Abteilung, oder ein Sachbestand
  ohne Datum.
- **niedrig** — ein Nummernzusatz, mehrere Mandanten in einer Zelle, eine Abteilung mit
  Schrägstrich (`C05/3`), oder ein erkennbarer Tippfehler in der Vorlage.

## Was die Datei bewusst nicht enthält

Lücken in der Nummernfolge, doppelt vergebene Nummern, Widersprüche zwischen den Spalten und die
Zuordnung zu einem Mandanten (`mandantId`) rechnet die App — dafür bräuchte der Erzeuger den
gesamten Bestand, die App kennt ihn schon. Ebenso die stabile Kennung jeder Zeile: Sie entsteht
beim Übernehmen und dient allein der Wiedererkennung bei einem zweiten Lauf.

Den Auftrag für den Erzeuger — für **einen** Jahrgang, mit den Sicherheitsstufen und den Formen
A/B — hält die App zum Kopieren bereit. Der Anwalt wählt den Jahrgang vorher aus (Vorgabe: der
kleinste noch fehlende, sonst das vorige Kalenderjahr); die Anleitung trägt ihn als festen
Bestandteil des Textes, nicht als Platzhalter, den der Erzeuger selbst füllen müsste.

## Was die App damit macht

`POST /api/RegisterImport` prüft, `POST /api/RegisterImport?uebernehmen=true` schreibt. **Beide
Aufrufe sind derselbe Code und liefern denselben Bericht** — nur `angewendet` unterscheidet sie.
Ohne `uebernehmen` verändert eine abgeschickte Datei nichts. Übernommen wird wahlweise **ein**
Jahrgang für sich (Knopf an dessen Befundkarte) oder **alle** Jahrgänge der Datei in einem Zug
(„Alle übernehmen") — technisch derselbe Aufruf, nur mit einer entsprechend geschnittenen Datei.

Je Zeile entscheidet der Dienst:

| Ergebnis | wann |
|---|---|
| `neu` | die Kombination aus Jahr, laufender Nummer und Nummernzusatz gibt es in der Historie noch nicht |
| `unveraendert` | die Kombination gibt es schon — die Datei überschreibt nie, auch vom Anwalt geänderte Felder bleiben unangetastet |
| `abgelehnt` | eine echte Doppelnummer: dieselbe Kombination aus Jahr, laufender Nummer und Nummernzusatz kommt in der Datei ein zweites Mal vor |

Der natürliche Schlüssel einer Zeile ist damit **(Jahr, laufende Nummer, Nummernzusatz)**, nicht
nur Jahr und Nummer — `10/19` und `10/19-I` sind zwei verschiedene Zeilen und bestehen
nebeneinander. Inhaltliche Befunde (Spalte 1 gegen Aktenzeichen, Abteilung gegen Rechtsgebiet,
unbekannte Abteilung, erkennbarer Tippfehler) lehnen **nie** eine Zeile ab — sie wird gespeichert,
wie sie in der Datei steht, und trägt den Befund. Abgelehnt wird ausschließlich die echte
Doppelnummer oben.

Ein zweiter Lauf desselben Jahrgangs ist damit harmlos: Jede bereits bekannte Zeile wird
`unveraendert` gemeldet, nichts wird zurückgesetzt. Geschrieben wird in **einer** Transaktion:
entweder der ganze Jahrgang oder nichts.

### Befunde je Jahrgang

Die Vorschau zeigt je Jahrgang: Zeilen gesamt, Lücken in der Nummernfolge, Doppelte, wie viele
Zeilen neu/unverändert/abgelehnt sind, wie viele **zu prüfen** sind (Sicherheit unter `hoch` oder
ein Befund an der Zeile), und die Abweichungen zwischen Abteilung und Rechtsgebiet. Ein Befund ist
immer ein Klartextsatz an der Zeile, z. B. „Abteilung C01a (Arbeitsrecht) widerspricht Spalte 3
„Verkehrsrecht" — übernommen wie in der Datei." Widersprüche werden **nie** still berichtigt: was
im Bestand steht, steht auch in der Zeile, dazu der Befund daneben.

### Stand

Ein **Stand** an einer Stelle sagt, welche Jahrgänge übernommen sind. Als fehlend gilt jeder
Jahrgang zwischen dem kleinsten und dem größten übernommenen, der nicht dabei ist — der Anwalt
sieht, dass 2021 fehlt, bevor er 2022 einliest. Dazu zeigt der Stand, welche Jahrgänge noch offene
Lücken in der laufenden Nummer haben.

### Bearbeiten mit Bestätigung

Eine historische Zeile lässt sich in der Registeransicht berichtigen, nur nach ausdrücklicher
Bestätigung. In der Spalte „Status" trägt sie dabei immer den Status **„Historie"** — auch nach
der Berichtigung —, denn sie ist und bleibt kein Vorgang. Und **nur** ihn: Was an der Zeile auffiel
(Befunde, eine Sicherheit unter `hoch`), steht im Herkunftskasten des Bearbeiten-Dialogs, den ein
Klick auf die Zeile öffnet — dort, wo der Anwalt es braucht, um es zu berichtigen. Ein zweiter Chip
in der Statusspalte machte aus einer Spalte mit einer Aussage eine mit zweien.

Die Registeransicht und der Word/PDF-Spiegel des Registers zeigen Historie und laufende Vorgänge
gemeinsam, aus derselben Quelle: Was auf dem Bildschirm steht, steht auch im Spiegel. Wechselt der
Jahrgang, steht davor eine fett gesetzte Jahreszeile — auf dem Bildschirm wie im Spiegel, wie im
bisherigen Word-Register der Kanzlei.

## Datenschutz

Die Vollfassung des Registers enthält echte Mandanten- und Gegnernamen, Aktenzeichen und
Unfalldaten. **Das Repository ist öffentlich.** Importdateien werden hochgeladen, nie committet;
Testdaten tragen erfundene Namen; Auszüge aus der Vollfassung gehören nicht in Issues, PRs oder
Commits.

## Die Gegenstücke im Code

Backend `Features/RegisterHistorie/`, Frontend `lib/features/register_import/` (Import-Seite) und
`lib/features/vorgaenge/` (Registeransicht, Bearbeiten historischer Zeilen). Der HTTP-Vertrag
steht wie immer in `docs/openapi.json`.
