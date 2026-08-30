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
}
