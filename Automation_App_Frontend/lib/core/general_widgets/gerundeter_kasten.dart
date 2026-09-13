import 'package:flutter/material.dart';

/// Farbige, gerundete Fläche mit Rand — und zwar als `Material`, nicht als
/// `Container`.
///
/// Der Unterschied ist keine Geschmacksfrage: `ListTile`, `InkWell` und alles
/// andere Antippbare zeichnet Hintergrund und Tipp-Kringel auf das nächste
/// `Material` **darüber**. Ein `Container` ist keins, der Kringel landete also
/// hinter der Kastenfarbe und bliebe unsichtbar — seit Flutter 3.47 ist das
/// eine Zusicherung und kein stiller Schönheitsfehler mehr. Dieser Kasten ist
/// selbst die Fläche, auf der gezeichnet wird.
///
/// Und er schneidet sie an seinen eigenen Ecken ab (`Clip.antiAlias`): Ein
/// durchsichtiges `Material` als Zwischenschicht täte das nicht — der Kringel
/// einer Kopfzeile, die bis an den Rand reicht, füllte dann die Ecken quadratisch
/// aus, die der Kasten gerade gerundet hat, und übermalte dort den Rand.
///
/// Sonst verhält er sich wie der `Container`, den er ersetzt. Beides braucht es,
/// weil ein `Material` mehr tut als malen:
/// - Die Schrift darin erbt weiter, was von außen gilt, statt auf `bodyMedium`
///   zurückzufallen — `Material` setzt sonst einen eigenen `DefaultTextStyle`.
/// - Farb- und Formwechsel springen, statt über `kThemeChangeDuration` zu
///   laufen. Sonst zöge ein Wechsel der Schriftstufe eine Animation nach sich,
///   die es vorher nicht gab.
class GerundeterKasten extends StatelessWidget {
  /// Füllfarbe der Fläche.
  final Color farbe;

  /// Randfarbe. Ohne Angabe bleibt der Kasten randlos.
  final Color? randfarbe;

  /// Eckenradius.
  final double rundung;

  /// Innenabstand. Ohne Angabe liegt der Inhalt am Rand — richtig für Inhalte,
  /// die ihre Ränder selbst mitbringen (eine Kopfzeile mit eigenem
  /// `tilePadding` etwa).
  final EdgeInsetsGeometry? polsterung;

  final Widget child;

  const GerundeterKasten({
    super.key,
    required this.farbe,
    required this.child,
    this.randfarbe,
    this.rundung = 12,
    this.polsterung,
  });

  @override
  Widget build(BuildContext context) {
    final rand = randfarbe;
    final abstand = polsterung;

    return Material(
      color: farbe,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rundung),
        side: rand == null ? BorderSide.none : BorderSide(color: rand),
      ),
      clipBehavior: Clip.antiAlias,
      textStyle: DefaultTextStyle.of(context).style,
      animationDuration: Duration.zero,
      child: abstand == null ? child : Padding(padding: abstand, child: child),
    );
  }
}
