import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';

/// Ein Eingabefeld im Kopf der Vollmacht (§4.11), in der Reihenfolge des
/// Formulars. [name] ist der Schlüssel des Felds im Dialog
/// (`vollmacht-<name>`) — wer umbenennt, bricht die Schlüssel, auf die Tests
/// und die Bedienung von außen zielen.
///
/// [beschriftung] steht am Feld und, für ein Feld, das frei bleibt, auch in
/// der Zeile über den Knöpfen — beides muss gleich lauten, sonst sucht der
/// Anwalt ein Feld, das es so nicht gibt.
enum VollmachtFeld {
  vorname('Vorname', ['MandantVorname', 'MandantName'], schreiblinie: true),
  nachname('Nachname', ['MandantNachname', 'MandantName'], schreiblinie: true),
  strasse('Straße und Hausnummer', [
    'MandantStrasse',
    'MandantAnschrift',
  ], schreiblinie: true),
  plz('PLZ', ['MandantPlz', 'MandantAnschrift'], schreiblinie: true),
  ort('Ort', ['MandantOrt', 'MandantAnschrift'], schreiblinie: true),
  telefon('Telefon', ['MandantTelefon'], schreiblinie: true),
  email('E-Mail', ['MandantEmail'], schreiblinie: true),

  /// Speist „wegen" (Unfallsachen). Die Vorlagen der Kanzlei führen das Datum
  /// nicht als eigenen Platzhalter; eine, die es tut, bekommt es trotzdem —
  /// der Dienst setzt `{{Unfalldatum}}` ein, leer als Linie.
  unfalldatum('Unfalldatum', ['Wegen', 'Unfalldatum']),

  /// Speist nur „wegen" (Bußgeldsachen); geht nicht an den Dienst.
  tatdatum('Tatdatum', ['Wegen']),
  inSachen('in Sachen', ['InSachen']),
  wegen('wegen', ['Wegen']);

  final String beschriftung;

  /// Die Platzhalter, in die das Feld eingeht; steht einer davon in der
  /// Vorlage, gehört das Feld aufs Papier. Vorname und Nachname zählen auch
  /// bei `MandantName`, Straße, PLZ und Ort auch bei `MandantAnschrift` —
  /// die Zusammensetzungen, die der Dienst daraus bildet.
  final List<String> platzhalter;

  /// Ob der Dienst einen leeren Wert als Schreiblinie druckt (#171). Nur die
  /// Mandantenfelder; „in Sachen" und „wegen" bleiben leer ohne Linie, die
  /// Daten stehen als Linie schon in der Vorbelegung von „wegen".
  final bool schreiblinie;

  const VollmachtFeld(
    this.beschriftung,
    this.platzhalter, {
    this.schreiblinie = false,
  });

  /// Der Wert dieses Felds in [kopf].
  String wert(VollmachtKopfdaten kopf) => switch (this) {
    VollmachtFeld.vorname => kopf.vorname,
    VollmachtFeld.nachname => kopf.nachname,
    VollmachtFeld.strasse => kopf.strasse,
    VollmachtFeld.plz => kopf.plz,
    VollmachtFeld.ort => kopf.ort,
    VollmachtFeld.telefon => kopf.telefon,
    VollmachtFeld.email => kopf.email,
    VollmachtFeld.unfalldatum => kopf.unfalldatum,
    VollmachtFeld.tatdatum => kopf.tatdatum,
    VollmachtFeld.inSachen => kopf.inSachen,
    VollmachtFeld.wegen => kopf.wegen,
  };
}
