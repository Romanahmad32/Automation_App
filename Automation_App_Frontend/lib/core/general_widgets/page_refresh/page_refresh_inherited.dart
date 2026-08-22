import 'package:automation_app/core/general_widgets/page_refresh/page_refresh_controller.dart';
import 'package:flutter/material.dart';

/// Trägt den [PageRefreshController] durch den Teilbaum, den
/// `PageRefreshScope` aufspannt.
///
/// Der Typ wird über `dependOnInheritedWidgetOfExactType` nachgeschlagen und
/// muss deshalb öffentlich sein: eine private Klasse ist außerhalb ihrer Datei
/// kein benennbarer Typ mehr.
class PageRefreshInherited extends InheritedWidget {
  const PageRefreshInherited({
    super.key,
    required this.controller,
    required this.generation,
    required super.child,
  });

  final PageRefreshController controller;

  /// Zählt hoch, sobald die Seite zurückgesetzt wurde; nur daran hängt die
  /// Benachrichtigung der Abhängigen.
  final int generation;

  @override
  bool updateShouldNotify(PageRefreshInherited oldWidget) =>
      generation != oldWidget.generation;
}
