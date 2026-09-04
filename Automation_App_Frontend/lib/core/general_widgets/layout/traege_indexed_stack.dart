import 'package:flutter/material.dart';

/// [IndexedStack], der ein Kind erst baut, wenn es zum ersten Mal gezeigt
/// wird — und es danach am Leben lässt.
///
/// Er ersetzt in den Einstellungen die `TabBarView`. Der Unterschied, auf den
/// es ankommt: Die `TabBarView` **schiebt** beim Reiterwechsel den ganzen
/// Inhalt seitlich vorbei. Sobald die Abschnittswahl aber im Reiter selbst
/// sitzt statt in einer Leiste darüber, würde sie mitwandern — die
/// Navigationszeile liefe unter dem Finger weg. Der Stack wechselt ohne
/// Bewegung; weil jeder Reiter dieselbe Zeile an derselben Stelle zeichnet,
/// sieht man nur den Inhalt darunter wechseln.
///
/// Das Zögern ist die zweite Hälfte: Ein gewöhnlicher [IndexedStack] baut alle
/// Kinder sofort, also auch die fünf Reiter, die niemand geöffnet hat — samt
/// ihrer Blocs und Netzabfragen. Gebaut wird deshalb nur, was schon einmal
/// sichtbar war; danach bleibt es stehen, mit seinem Zustand (Formulare,
/// Scrollposition), wie es die `TabBarView` nur mit `AutomaticKeepAlive`
/// hinbekommt.
class TraegeIndexedStack extends StatefulWidget {
  /// Das Kind, das gezeigt wird.
  final int index;

  final List<Widget> children;

  const TraegeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<TraegeIndexedStack> createState() => _TraegeIndexedStackState();
}

class _TraegeIndexedStackState extends State<TraegeIndexedStack> {
  /// Welche Kinder schon einmal sichtbar waren. Wächst nur — ein einmal
  /// aufgebauter Reiter wird nicht wieder weggeworfen, sonst verlöre er beim
  /// Zurückwechseln seine Eingaben.
  final Set<int> _gezeigt = {};

  @override
  void initState() {
    super.initState();
    _gezeigt.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant TraegeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Kein setState: Auf diesen Aufruf folgt ohnehin ein build.
    _gezeigt.add(widget.index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      // Die Reiter füllen die Fläche; ohne das schrumpfte ein Scrollbereich
      // auf die Höhe seines Inhalts und der kurze Reiter „Über" klebte oben.
      sizing: StackFit.expand,
      children: [
        for (final (i, kind) in widget.children.indexed)
          if (_gezeigt.contains(i)) kind else const SizedBox.shrink(),
      ],
    );
  }
}
