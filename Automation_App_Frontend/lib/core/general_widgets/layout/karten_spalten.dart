import 'package:flutter/material.dart';

/// Legt Formularkarten **nebeneinander**, sobald der Platz dafür reicht, und
/// stapelt sie darunter untereinander.
///
/// Der Anlass ist ein Windows-Desktop: Auf einem großen Monitor bleiben neben
/// einer mittigen Formularspalte schnell mehrere hundert Pixel leer, während
/// dieselbe Seite auf einem halben Monitor eng wird. Beides an einer Stelle zu
/// entscheiden ist der Zweck dieses Bausteins — wer die Grenze je Seite setzt,
/// setzt sie an der nächsten Seite anders.
///
/// Die Aufteilung ist **fachlich**, nicht automatisch: Der Aufrufer sagt, was
/// nach [links] und was nach [rechts] gehört (etwa Stammdaten | Ordner). Ein
/// Mauerwerk-Layout, das Karten nach Höhe verteilt, brächte dieselben Karten
/// bei jeder Größenänderung in eine andere Reihenfolge — auf einer
/// Einstellungsseite, die man sich merkt, ist das schlechter als eine feste,
/// erklärbare Zuordnung.
///
/// Unterhalb von [zweiSpaltenAb] laufen beide Listen zu **einer** Spalte
/// zusammen, `links` zuerst. Deshalb gehört nach `links`, was zuerst gelesen
/// werden soll.
class KartenSpalten extends StatelessWidget {
  /// Ab dieser verfügbaren Breite stehen zwei Spalten nebeneinander.
  ///
  /// Zwei Spalten sind erst dann besser als eine, wenn jede noch etwa 520 px
  /// behält — darunter wird jedes Feld schmaler als in der einspaltigen
  /// Fassung, und die zweite Spalte gewinnt nichts.
  static const double zweiSpaltenAb = 1080;

  /// Obergrenze für den zweispaltigen Fall. Ohne sie liefe die Zeilenlänge auf
  /// einem 4K-Schirm aus dem Ruder.
  static const double maxBreiteZweispaltig = 1300;

  /// Obergrenze für den einspaltigen Fall — großzügiger als die 560 px, die
  /// hier früher standen, aber weit genug von der Bildschirmbreite entfernt,
  /// dass eine Beschriftung neben ihrem Feld bleibt.
  static const double maxBreiteEinspaltig = 760;

  /// Die Karten der linken (bzw. bei einer Spalte: der oberen) Hälfte.
  final List<Widget> links;

  /// Die Karten der rechten Hälfte. Leer heißt: immer einspaltig.
  final List<Widget> rechts;

  /// Überschreibt [maxBreiteEinspaltig] für Inhalte, die von Breite leben —
  /// eine Tabellenvorschau etwa liest sich in 760 px schlechter als in 1000.
  final double? breiteEinspaltig;

  /// Abstand zwischen den Karten und zwischen den Spalten.
  final double abstand;

  const KartenSpalten({
    super.key,
    required this.links,
    this.rechts = const [],
    this.breiteEinspaltig,
    this.abstand = 16,
  });

  Widget _spalte(List<Widget> karten) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: abstand,
    children: karten,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final zweispaltig =
            rechts.isNotEmpty && constraints.maxWidth >= zweiSpaltenAb;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: zweispaltig
                  ? maxBreiteZweispaltig
                  : (breiteEinspaltig ?? maxBreiteEinspaltig),
            ),
            child: zweispaltig
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: abstand,
                    children: [
                      Expanded(child: _spalte(links)),
                      Expanded(child: _spalte(rechts)),
                    ],
                  )
                : _spalte([...links, ...rechts]),
          ),
        );
      },
    );
  }
}
