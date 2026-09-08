/// Der Arbeitsauftrag für den Erzeuger der Registerdatei — zum Kopieren
/// gedacht (§6.2).
///
/// Der Erzeuger sitzt nicht in dieser App: Die Datei entsteht auf dem
/// Kanzleirechner aus dem Word-Register, durch ein Programm, das den
/// Markdown-Auszug eines Jahrgangs lesen kann. Damit ist dieser Text die
/// eigentliche Schnittstelle — und er gehört neben das Format, das er
/// beschreibt, nicht in eine Anleitung, die man erst suchen muss.
///
/// Der Auftrag gilt **einem Jahrgang**, nicht dem ganzen Register. Zwei Gründe,
/// die beide teuer bezahlt wurden: Tausende Zeilen passen nicht in eine
/// Sitzung — der Erzeuger bricht ab oder wird gegen Ende ungenau, und die Datei
/// sieht trotzdem vollständig aus. Und die laufende Nummer läuft je Jahr
/// lückenlos von 1 aufwärts; nur jahrgangsweise lässt sich daran ablesen, ob
/// eine Zeile verloren ging.
///
/// Dieselbe Beschreibung ausführlicher: `docs/REGISTER_IMPORT.md`. Ändert sich
/// das Format, ändern sich beide.
class RegisterImportAnleitung {
  const RegisterImportAnleitung._();

  /// Der Platzhalter, den [textFuer] durch den gewählten Jahrgang ersetzt.
  static const jahrgangsPlatzhalter = '<JAHRGANG>';

  /// Der Aufbau der Antwortdatei (Fassung 1) samt Feldregeln.
  static const dateiaufbau = r'''
Antwort: eine JSON-Datei in diesem Aufbau (Fassung 1)
{
  "version": 1,
  "jahrgang": <JAHRGANG>,
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
      "hinweise": ["Nummer traegt den Zusatz -I", "Sachbestand ohne Datum"]
    }
  ]
}

Regeln
- "laufendeNummer": die Zahl aus dem Aktenzeichen, ohne fuehrende Null.
- "spalte1": was in Spalte 1 der Tabelle stand, unveraendert. Weicht es von der
  Nummer im Aktenzeichen ab, bleibt beides stehen — die App meldet es.
- "abteilung": Kuerzel ohne Leerzeichen ("C 03o" -> "C03o").
  "abteilungRoh": die Schreibweise aus der Vorlage, unveraendert.
- Form A "Name ./. Gegner  Sachbestand v. Datum": "mandant", "gegner",
  "sachbestand", "unfalldatum" fuellen, "sachart" leer lassen.
  Form B "Sachart Name  Sachbestand": "sachart" und "mandant" fuellen,
  "gegner" leer lassen.
- "freitext": die Zelle im Wortlaut — der Beleg, an dem sich jede Deutung
  nachpruefen laesst. Immer mitgeben.
- "sicherheit": "hoch" bei vollstaendiger Form A; "mittel" bei Form B,
  fehlender Abteilung oder Sachbestand ohne Datum; "niedrig" bei
  Nummernzusatz, mehreren Mandanten in einer Zelle, Abteilung mit
  Schraegstrich oder erkennbarem Tippfehler.
- "hinweise": was dir aufgefallen ist, in ganzen Saetzen.
- Die Datei darf mehrfach eingelesen werden; ein zweiter Lauf aendert nichts.
''';

  /// Der Auftrag für [jahrgang] — Eingabe ist der Markdown-Ausschnitt genau
  /// dieses Jahres, Ausgabe eine Datei nur für ihn.
  static String textFuer(int jahrgang) =>
      _auftrag.replaceAll(jahrgangsPlatzhalter, '$jahrgang');

  static const _auftrag =
      r'''
Aufgabe: Erzeuge aus dem Word-Register der Kanzlei eine Importdatei fuer den
Jahrgang <JAHRGANG> (register-<JAHRGANG>.json, Aufbau unten).

Eingabe: der Markdown-Auszug der Registertabelle. Bearbeite GENAU die Zeilen des
Jahrgangs <JAHRGANG> — die Jahreszeile darueber und darunter grenzt ihn ab; ab
2025 fehlt sie, dann steht das Jahr im Aktenzeichen ("01/25").

Vorgehen
1. Uebernimm jede Zeile des Jahrgangs, auch die krummen. Die laufende Nummer
   laeuft lueckenlos von 01 aufwaerts; fehlt eine, hast du eine Zeile
   uebersehen. Zaehle am Ende nach.
2. Berichtige NICHTS. Tippfehler, widersprueckliche Angaben und uneinheitliche
   Abteilungskuerzel bleiben stehen, wie sie im Register stehen — die App
   erkennt sie und legt sie dem Anwalt vor. Was du glaettest, ist verloren.
3. Rate nichts. Ein leeres Feld ist besser als ein erfundenes.
4. Setze "sicherheit" ehrlich (Stufen unten) und schreibe unter "hinweise",
   was dir aufgefallen ist.
5. Gib "freitext" immer mit — die Zelle im Wortlaut ist der Beleg.

''' +
      dateiaufbau;
}
