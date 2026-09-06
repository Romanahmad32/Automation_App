import 'package:flutter/material.dart';

/// Eine Spalte der Feldertabelle: ihre Aufschrift in der Kopfzeile und der
/// Platz, den sie in jeder Zeile bekommt.
///
/// Entweder [breite] (feste Pixel) **oder** [flex] (Anteil am Rest) ist
/// gesetzt — die beiden Konstruktoren lassen nichts anderes zu.
class FelderSpalte {
  /// Aufschrift in der Kopfzeile. Leer heißt: Die Spalte trägt keine — ein
  /// Ziehgriff oder ein Symbolknopf erklärt sich selbst, und ein Kopftext über
  /// einem 48 px breiten Knopf wäre ohnehin nur ein Kürzel mit Auslassung.
  final String beschriftung;

  /// Feste Breite in logischen Pixeln; null heißt: Die Spalte teilt sich den
  /// Rest über [flex].
  final double? breite;

  /// Anteil am Restplatz; null bei fester [breite].
  final int? flex;

  /// Steckt als Schlüssel in jeder Zelle — dadurch sind Kopfzeile und
  /// Feldzeile Spalte für Spalte vergleichbar (`felder_spalten_test.dart`).
  final String schluessel;

  const FelderSpalte.fest({
    required this.schluessel,
    required this.breite,
    this.beschriftung = '',
  }) : flex = null;

  const FelderSpalte.flexibel({
    required this.schluessel,
    required this.flex,
    required this.beschriftung,
  }) : breite = null;

  Key get zellenSchluessel => ValueKey('felderspalte_$schluessel');
}

/// **Die eine** Spaltenbeschreibung der Feldertabelle im Vorlageneditor —
/// Kopfzeile und Feldzeile bauen beide daraus.
///
/// Vorher stand die Aufteilung zweimal da: eine Flex-Liste im Tabellenkopf,
/// eine zweite in der Feldzeile, dazu je eigene Platzhalter für Ziehgriff und
/// Löschen-Knopf. Die beiden liefen bei jeder Änderung auseinander — der Kopf
/// „ANFORDERUNG" stand irgendwann über der Datenquelle. Mit einer Liste ist
/// das keine Frage der Sorgfalt mehr: Wer eine Spalte ergänzt, ergänzt sie an
/// genau einer Stelle, und [zeile] besteht darauf, dass beide Seiten gleich
/// viele Zellen liefern.
///
/// Vorbild ist `form_template_table_layout.dart`, das dasselbe für die
/// Vorlagenübersicht tut.
abstract final class FelderSpalten {
  /// Ziehgriff zum Umsortieren.
  static const griff = FelderSpalte.fest(schluessel: 'griff', breite: 40);

  /// Der Feldname. Breiteste Spalte, denn er ist zugleich der
  /// Platzhaltername: Was hier steht, sucht das Backend in der Word-Datei.
  static const bezeichnung = FelderSpalte.flexibel(
    schluessel: 'bezeichnung',
    flex: 5,
    beschriftung: 'Bezeichnung = Platzhaltername',
  );

  static const typ = FelderSpalte.fest(
    schluessel: 'typ',
    breite: 140,
    beschriftung: 'Typ',
  );

  static const datenquelle = FelderSpalte.flexibel(
    schluessel: 'datenquelle',
    flex: 4,
    beschriftung: 'Datenquelle',
  );

  /// Breit genug für die eigene Aufschrift, nicht nur für die Checkbox: Eine
  /// Spalte, deren Kopf schon bei voller Fensterbreite mit Auslassung
  /// abgeschnitten wäre, hätte gar keine.
  static const pflicht = FelderSpalte.fest(
    schluessel: 'pflicht',
    breite: 88,
    beschriftung: 'Pflicht',
  );

  /// Chevron: klappt das Seltene unter der Zeile auf (Datums-Vorbelegung,
  /// Namenshinweis).
  static const aufklapper = FelderSpalte.fest(
    schluessel: 'aufklapper',
    breite: 48,
  );

  static const loeschen = FelderSpalte.fest(schluessel: 'loeschen', breite: 48);

  /// Links nach rechts, so wie sie stehen.
  static const List<FelderSpalte> alle = [
    griff,
    bezeichnung,
    typ,
    datenquelle,
    pflicht,
    aufklapper,
    loeschen,
  ];

  /// Abstand zwischen zwei Spalten.
  static const double abstand = 8;

  /// Höhe einer zugeklappten Feldzeile.
  ///
  /// Als **Mindesthöhe**, nicht als feste: Bei der größten Schriftstufe
  /// (Issue #57) wächst jedes Eingabefeld mit, und eine feste Höhe schnitte
  /// die Zeile ab, statt sie mitwachsen zu lassen. Zweck der Zahl ist, dass
  /// alle Zeilen gleich hoch sind — auch die ohne Warnung und die ohne
  /// Datumsfeld —, damit das Auge die Spalten von oben nach unten verfolgen
  /// kann.
  static const double zeilenHoehe = 56;

  /// Seitlicher Rand, den die Kopfzeile braucht, um über den Zellen der
  /// Feldzeile zu stehen: deren Aussenabstand (10) + Rahmen (1) +
  /// Innenabstand (8). Steht hier, weil Kopf und Zeile sonst genau um diese
  /// Zahl auseinanderliefen.
  static const double kopfEinrueckung = 19;

  /// Baut eine Zeile aus [zellen] — eine je Spalte, in der Reihenfolge von
  /// [alle].
  static Widget zeile(List<Widget> zellen) {
    assert(
      zellen.length == alle.length,
      'Die Feldertabelle hat ${alle.length} Spalten, geliefert wurden '
      '${zellen.length}. Kopfzeile und Feldzeile bauen aus derselben Liste — '
      'eine neue Spalte gehört in FelderSpalten.alle, nicht nur hierher.',
    );
    return Row(
      spacing: abstand,
      children: [
        for (var i = 0; i < alle.length; i++) _zelle(alle[i], zellen[i]),
      ],
    );
  }

  /// Die `SizedBox` trägt den Schlüssel und bekommt in der flexiblen Variante
  /// eine feste Breitenvorgabe vom `Expanded` — dadurch **ist** ihre Größe die
  /// Spaltenbreite und lässt sich im Test messen.
  static Widget _zelle(FelderSpalte spalte, Widget inhalt) {
    final zelle = SizedBox(
      key: spalte.zellenSchluessel,
      width: spalte.breite,
      child: inhalt,
    );
    final flex = spalte.flex;
    return flex == null ? zelle : Expanded(flex: flex, child: zelle);
  }
}
