import 'package:flutter/material.dart';

/// Der eine Drehknopf für den Schriftgrad der gesamten Oberfläche (Issue #57).
///
/// Anlass: Die Schrift war an vielen Stellen zu klein. Der Anwalt liest hier
/// den ganzen Arbeitstag Aktenzeichen, Beträge und Fristen an einem
/// Desktop-Monitor — die Material-3-Vorgaben sind dagegen für ein Telefon auf
/// Armlänge entworfen. Angehoben wird deshalb **einmal an der Skala** und
/// nicht Stelle für Stelle: `MaterialTheme.theme` zieht jedes `TextTheme`
/// durch [anheben], und damit wachsen Standard- und Kanzlei-Design, hell wie
/// dunkel, gemeinsam mit. Eine Einzelstelle, die ihre Größe selbst verdrahtet,
/// bliebe dabei zurück und risse ein Loch in die Hierarchie — darüber wacht
/// `test/architecture/schriftgroesse_test.dart`.
///
/// Was die Anhebung aus den Material-3-Rollen macht:
///
/// | Rolle         | vorher | nachher |
/// |---------------|--------|---------|
/// | `labelSmall`  |     11 |      13 |
/// | `bodySmall`   |     12 |      14 |
/// | `labelMedium` |     12 |      14 |
/// | `bodyMedium`  |     14 |      16 |
/// | `labelLarge`  |     14 |      16 |
/// | `titleSmall`  |     14 |      16 |
/// | `titleMedium` |     16 |      18 |
/// | `bodyLarge`   |     16 |      18 |
/// | `titleLarge`  |     22 |      24 |
///
/// **Warum ein Zuschlag und kein Faktor.** Zu klein waren die *kleinen* Stile:
/// Hilfstexte unter den Feldern, Chip- und Knopfbeschriftungen, Tabellen- und
/// Listenzeilen. Ein fester Zuschlag gibt genau denen am meisten —
/// `labelSmall` wächst um 18 %, `titleLarge` nur um 9 %, und die
/// Display-Stile (bis 57 px) bleiben praktisch, wie sie sind. Ein Faktor täte
/// das Gegenteil: Er ließe die Hilfstexte fast dort, wo sie waren, und bliese
/// die großen Überschriften ins Groteske auf, wo sie in ihren Zeilen nicht
/// mehr umbrechen.
///
/// **Warum nicht `MediaQuery.textScaler`.** Der Skalierer gehört dem
/// Anwender: Er ist die Barrierefreiheits-Einstellung des Betriebssystems und
/// wirkt *zusätzlich* zu dem, was hier steht. Ihn von der App aus zu setzen
/// nähme dem Anwalt genau den Regler weg, um den es geht. Er ändert außerdem
/// die Werte im `TextTheme` nicht — jede Stelle, die eine Höhe oder einen
/// Abstand an `textTheme.titleLarge!.fontSize` ausrichtet, rechnete weiter mit
/// der alten Zahl, und die Oberfläche wüchse nur halb mit.
abstract final class Schriftskala {
  /// Zuschlag in logischen Pixeln auf jede Rolle des `TextTheme`. Der eine
  /// Drehknopf für Issue #57 — wer die Oberfläche insgesamt größer oder
  /// wieder kleiner haben will, ändert diese Zahl und sonst nichts.
  static const double anhebung = 2;

  /// Wendet die Anhebung auf [textTheme] an.
  ///
  /// Farben bleiben Sache des Aufrufers: Welche Rolle welche
  /// `onSurface`-Variante bekommt, hängt am Farbschema und wird in
  /// `MaterialTheme.theme` direkt danach gesetzt.
  ///
  /// Der Umweg über [Typography.englishLike2021] ist kein Beiwerk, sondern
  /// der Kern: Ein `TextTheme` trägt seine Größen **nicht** von Haus aus.
  /// `ThemeData.light().textTheme` etwa besteht nur aus Farben und
  /// Schriftfamilie — die Größen (die „Geometrie") mischt Flutter erst weiter
  /// unten in `Theme.of` über `ThemeData.localize` dazu, je nach Schriftsystem
  /// des Gebietsschemas. Ein `apply(fontSizeDelta: …)` auf so ein TextTheme
  /// wirft eine Assertion, und ohne sie wäre es schlimmer: Die Anhebung fiele
  /// still aus, weil die Geometrie mit ihren alten Zahlen erst danach käme.
  /// Hier wird sie deshalb vorgezogen — dieselbe Verrechnung, die Flutter
  /// ohnehin vornimmt, nur früh genug, dass der Zuschlag darauf sitzt. Wer
  /// Größen mitbringt (im Betrieb: `createTextTheme` und
  /// `createKanzleiTextTheme`, beide auf `Theme.of` aufgebaut), behält seine:
  /// [TextTheme.merge] lässt die Werte des Aufrufers gewinnen.
  static TextTheme anheben(TextTheme textTheme) => Typography.englishLike2021
      .merge(textTheme)
      .apply(fontSizeDelta: anhebung);
}
