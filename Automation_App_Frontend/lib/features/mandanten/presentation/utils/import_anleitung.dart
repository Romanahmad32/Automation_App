/// Der Arbeitsauftrag für den Erzeuger der Importdatei — zum Kopieren gedacht.
///
/// Der Erzeuger sitzt nicht in dieser App: die Datei entsteht auf dem
/// Kanzleirechner, wo der Aktenbestand liegt, durch ein Programm, das Ordner
/// und Schreiben lesen kann. Damit ist dieser Text die eigentliche
/// Schnittstelle — und er gehört neben das Format, das er beschreibt, nicht in
/// eine Anleitung, die man erst suchen muss.
///
/// Es gibt ihn in **zwei Fassungen**, weil es zwei Betriebsarten gibt:
///
/// * [text] für den Lauf über den ganzen Stammordner — der Erzeuger sucht sich
///   seine Ordner selbst.
/// * [paketText] für den Lauf mit einem Arbeitspaket — die App gibt die Ordner
///   vor, und die Liste ist geschlossen.
///
/// Der Aufbau der Antwortdatei ([dateiaufbau]) ist in beiden Fällen derselbe
/// und steht deshalb genau einmal da: zweimal beschrieben liefen die Fassungen
/// beim ersten Formatwechsel auseinander, und die zweite fiele erst auf, wenn
/// eine Datei nicht mehr eingelesen werden kann.
///
/// Dieselbe Beschreibung ausführlicher: `docs/MANDANTEN_IMPORT.md`. Ändert sich
/// das Format, ändern sich beide.
class ImportAnleitung {
  const ImportAnleitung._();

  /// Der Aufbau der Antwortdatei (Fassung 1) samt Feldregeln — der Teil, den
  /// beide Aufträge wortgleich brauchen.
  static const dateiaufbau = r'''
Antwort: eine JSON-Datei in diesem Aufbau (Fassung 1)
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

  /// Der Auftrag ohne Arbeitspaket: der Erzeuger liest den Stammordner selbst.
  static const text =
      r'''
Aufgabe: Erzeuge aus dem Aktenbestand der Kanzlei eine Importdatei für die
Kanzlei-App (mandanten-import.json, Aufbau unten).

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

''' +
      dateiaufbau;

  /// Der Auftrag zu einem Arbeitspaket (`arbeitspaket-<nr>.json`).
  ///
  /// Er sagt vier Dinge, die der Auftrag ohne Paket nicht sagen kann und die
  /// jeweils einen bestimmten Schaden verhindern:
  ///
  /// * **Die Liste ist geschlossen.** Wer daneben greift, bearbeitet Ordner
  ///   doppelt — einmal hier und einmal im nächsten Paket — und erzeugt genau
  ///   die Dubletten, gegen die die Paketaufteilung gebaut wurde.
  /// * **Die bekannten Mandanten sind zu benutzen.** Ein zweiter Eintrag für
  ///   denselben Menschen ist die teuerste Art, sich zu irren.
  /// * **Nur nachlesen, wo es nötig ist.** Jeder geöffnete Unterordner kostet
  ///   Zeit auf einem Netzlaufwerk; wo Namensvorschlag oder bekannter Mandant
  ///   schon dastehen, bringt er nichts.
  /// * **Der Ordnername ist zeichengenau zu übernehmen.** Er ist das einzige
  ///   Band zwischen Paket und App: Zuordnung und Vermerk hängen daran, nicht
  ///   an einem Pfad und nicht an einer Nummer. Abgetippt oder gekürzt zeigt er
  ///   ins Leere — die App weist solche Zeilen inzwischen ab, aber die Arbeit
  ///   daran ist dann trotzdem verloren.
  static const paketText =
      r'''
Aufgabe: Ergänze das beiliegende Arbeitspaket der Kanzlei-App
(arbeitspaket-<nr>.json) zu einer Importdatei.

Das Paket nennt unter "ordner" die Akten-Ordner, um die es geht, und unter
"stammordner" den Pfad, unter dem sie liegen.

Vorgehen
1. Bearbeite GENAU die Ordner aus "ordner" — keine anderen. Die Liste ist
   geschlossen: was nicht darin steht, gehört zu einem anderen Paket und wird
   dort bearbeitet.
2. Nimm den Ordnernamen ZEICHENGENAU aus dem Paket in "aktenOrdnernamen".
   Er ist das einzige Band zwischen deiner Antwort und der App. Nicht abtippen,
   nicht kürzen, nicht berichtigen, auch wenn er schief aussieht.
3. Schau zuerst in "bekannteMandanten" nach. Steht der Mandant schon dort,
   übernimm seinen Namen unverändert, statt einen neuen anzulegen.
   "bekannterMandant" am Ordner nennt dir den wahrscheinlichen Treffer samt
   Begründung.
4. Lies nur DORT in die Unterordner, wo Namensvorschlag
   ("nameVorschlagVorname"/"nameVorschlagNachname") und "bekannterMandant"
   fehlen. Wo einer von beiden dasteht, reicht er.
5. Gehören mehrere Ordner des Pakets demselben Mandanten, ergibt das EINEN
   Eintrag mit mehreren Namen in "aktenOrdnernamen".
6. Ordner ohne Mandantenbezug (Buchhaltung, Vorlagen, Muster, Ablage) kommen
   nach "ohneMandantenbezug" statt in "mandanten".
7. Trage nur ein, was du wirklich gefunden hast. Rate nichts: ein leeres Feld
   ist besser als ein falsches, die App ergänzt Leerstellen später von selbst.
   Sie überschreibt aber niemals einen vorhandenen Wert.
8. Setze "sicherheit" ehrlich: "hoch" nur, wenn Name und Zuordnung belegt sind.
   "quelle" nennt die Datei oder den Ordner, aus dem die Angaben stammen.

Die Paketnummer gehört NICHT in die Antwort — die App erkennt das Paket an den
Ordnernamen.

''' +
      dateiaufbau;
}
