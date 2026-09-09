import 'package:flutter/material.dart';

/// Verbindet die laufende Statusprüfung in der Shell mit der Einstellungsansicht.
class SynchronisationsBereich extends InheritedWidget {
  final WidgetBuilder anzeige;

  const SynchronisationsBereich({
    super.key,
    required this.anzeige,
    required super.child,
  });

  @override
  bool updateShouldNotify(SynchronisationsBereich oldWidget) => true;
}

class SynchronisationsAnsicht extends StatelessWidget {
  const SynchronisationsAnsicht({super.key});

  @override
  Widget build(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<SynchronisationsBereich>()!
      .anzeige(context);
}
