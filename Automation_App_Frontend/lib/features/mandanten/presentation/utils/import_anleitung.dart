/// Der Arbeitsauftrag für den Erzeuger der Importdatei — zum Kopieren gedacht.
///
/// Der Erzeuger sitzt nicht in dieser App: die Datei entsteht auf dem
/// Kanzleirechner, wo der Aktenbestand liegt, durch ein Programm, das Ordner
/// und Schreiben lesen kann. Damit ist dieser Text die eigentliche
/// Schnittstelle — und er gehört neben das Format, das er beschreibt, nicht in
/// eine Anleitung, die man erst suchen muss.
///
/// Dieselbe Beschreibung ausführlicher: `docs/MANDANTEN_IMPORT.md`.
class ImportAnleitung {
  const ImportAnleitung._();

  static const text = r'''
Aufgabe: Erzeuge aus dem Aktenbestand der Kanzlei eine Importdatei für die
Kanzlei-App (mandanten-import.json, Format unten).

Stammordner: <Pfad zum Akten-Stammordner hier eintragen>

Vorgehen
1. Lies die Ordnernamen der ersten Ebene unter dem Stammordner.
2. Ermittle je Ordner den Mandanten — aus dem Ordnernamen und, wo das nicht
   reicht, aus den Schreiben im Ordner (Anschrift, Kennzeichen, Telefon,
   E-Mail).
3. Trage nur ein, was du wirklich gefunden hast. Rate nichts: ein leeres Feld
   ist besser als ein falsches, die App ergänzt Leerstellen später von selbst.
   Sie überschreibt aber niemals einen vorhandenen Wert.
4. Gehören mehrere Ordner demselben Mandanten, ergibt das EINEN Eintrag mit
   mehreren Namen in "aktenOrdnernamen".
5. Ordner ohne Mandantenbezug (Buchhaltung, Vorlagen, Muster, Ablage) kommen
   nach "ohneMandantenbezug" statt in "mandanten".
6. Setze "sicherheit" ehrlich: "hoch" nur, wenn Name und Zuordnung belegt sind.
   "quelle" nennt die Datei oder den Ordner, aus dem die Angaben stammen.

Format (Version 1)
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
      "aktenOrdnernamen": ["VUnfallursache Schmidt"],
      "kennzeichen": ["HG-E 1427"],
      "quelle": "VUnfallursache Schmidt/Unfall v. 12.05.2019/Schreiben.docx",
      "sicherheit": "hoch"
    }
  ],
  "ohneMandantenbezug": ["Buchhaltung 2019", "Vorlagen"]
}

Regeln
- "anrede": "herr", "frau" oder "keine".
- "kennzeichen": mit Bindestrich, z. B. "HG-E 1427".
- "sicherheit": "hoch", "mittel" oder "niedrig".
- "aktenOrdnernamen": nur der Ordnername, kein Pfad.
- Außer "vorname"/"nachname" darf jedes Feld leer bleiben.
- Die Datei darf mehrfach eingelesen werden; ein zweiter Lauf ändert nichts.
''';

  /// Der Auftrag im **Paketbetrieb** — er reist in der Paketdatei selbst mit
  /// (`ArbeitspaketBau`), statt daneben zu liegen.
  ///
  /// Er ersetzt [text] nicht, sondern setzt darauf auf: Das Paket ist die
  /// Eingabe, die Antwort bleibt das dort beschriebene Format der Fassung 1.
  /// Der Unterschied ist der Zuschnitt — statt 4040 Ordner in einer Sitzung
  /// bearbeitet der Erzeuger rund 200, und für einen großen Teil davon steht
  /// die Antwort schon in der Datei.
  static const paketText = r'''
Aufgabe: Bearbeite dieses Arbeitspaket und erzeuge daraus eine Importdatei für
die Kanzlei-App (Format der Fassung 1, unten).

Die Liste unter "ordner" ist GESCHLOSSEN
- Bearbeite genau diese Ordner. Keine anderen, auch wenn sie danebenliegen.
- Erfinde keinen Ordner dazu. Was nicht in der Liste steht, gehört in ein
  anderes Paket, und die App führt darüber Buch.
- Der "ordnername" ist das einzige Band zur App. Übernimm ihn ZEICHENGENAU in
  "aktenOrdnernamen" — nicht umschreiben, nicht trimmen, Groß- und
  Kleinschreibung und Leerzeichen unverändert lassen. Ein geänderter Name
  trifft auf der Platte keinen Ordner mehr.

Was schon in der Datei steht (und nicht noch einmal gesucht werden muss)
- "aktentyp": aus dem Präfix des Ordnernamens erkannt.
- "vorschlagVorname"/"vorschlagNachname": aus dem Ordnernamen abgeleitet.
- "mandantImRegister": der Mandant, den die App zu diesem Ordner schon kennt.
  Ist er gefüllt, genügt es, den Ordner diesem Mandanten anzuhängen — eine
  Zeile mit dessen Namen und dem Ordnernamen. Stammdaten brauchst du dafür
  nicht zu suchen; die App ergänzt nie über einen vorhandenen Wert hinweg.

Wo NICHT gelesen werden muss
- Bei Straf-, Bußgeld- und Familiensachen: Diese App bearbeitet
  Verkehrsunfallsachen. Aus solchen Ordnern werden in aller Regel keine
  Stammdaten gebraucht — Name und Ordner reichen.
- Bei jedem Ordner mit "mandantImRegister" (siehe oben).
Lies die Schreiben im Ordner nur dort, wo Vorname oder Anschrift fehlen und
der Ordner eine Verkehrsunfallsache ist. Das Lesen ist der teure Teil.

"bekannteMandanten" zuerst prüfen
- Bevor du einen Mandanten neu anlegst, sieh in "bekannteMandanten" nach:
  Name, bisherige Ordner und Kennzeichen stehen dort.
- Passt eine Schreibvariante desselben Menschen ("Schmitt"/"Schmidt",
  "Dr. Schmidt"), führe sie DORTHIN zusammen und schreibe den Namen so, wie er
  in "bekannteMandanten" steht. Ein zweiter Eintrag wäre eine Dublette, die
  hinterher von Hand aufgelöst werden muss.
- Mehrere Ordner desselben Mandanten ergeben EINEN Eintrag mit mehreren Namen
  in "aktenOrdnernamen".

Die Antwortdatei
Sie bleibt das bekannte Format der Fassung 1 — dasselbe, das die App ohne
Paketbetrieb erwartet: ein Objekt mit "version": 1, "mandanten" und
"ohneMandantenbezug". Das Paket ist nur die Eingabe und wird nicht
zurückgeschickt.

Format (Version 1)
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
      "aktenOrdnernamen": ["VUnfallursache Schmidt"],
      "kennzeichen": ["HG-E 1427"],
      "quelle": "VUnfallursache Schmidt/Unfall v. 12.05.2019/Schreiben.docx",
      "sicherheit": "hoch"
    }
  ],
  "ohneMandantenbezug": ["Buchhaltung 2019", "Vorlagen"]
}

Regeln
- "anrede": "herr", "frau" oder "keine".
- "kennzeichen": mit Bindestrich, z. B. "HG-E 1427".
- "sicherheit": "hoch", "mittel" oder "niedrig".
- "aktenOrdnernamen": nur der Ordnername, kein Pfad, zeichengenau aus "ordner".
- Rate nichts: ein leeres Feld ist besser als ein falsches.
- Ordner ohne Mandantenbezug (Buchhaltung, Vorlagen, Muster, Ablage) kommen
  nach "ohneMandantenbezug" statt in "mandanten".
- Die Datei darf mehrfach eingelesen werden; ein zweiter Lauf ändert nichts.
''';
}
