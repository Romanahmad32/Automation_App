import 'package:flutter/material.dart';

/// Stellt einen "Seite neu laden"-Mechanismus bereit.
///
/// Wird [PageRefreshController.refresh] aufgerufen, baut der umschlossene
/// Teilbaum — inklusive der `BlocProvider` aus `wrappedRoute` — komplett neu
/// auf. Dadurch werden Factory-Blocs, lokale `State`s, Text-Controller und
/// reactive_forms in ihren Anfangszustand zurückgesetzt; per `.value`
/// eingebundene Singleton-Blocs erhalten ihr Lade-Event erneut.
///
/// Einsatz in `wrappedRoute`:
/// ```dart
/// Widget wrappedRoute(BuildContext context) => PageRefreshScope(
///       builder: (context) => BlocProvider(
///         create: (_) => getIt<MyBloc>(),
///         child: this,
///       ),
///     );
/// ```
/// und in der `AppBar` der Seite:
/// ```dart
/// actions: const [PageRefreshButton()],
/// ```
class PageRefreshScope extends StatefulWidget {
  const PageRefreshScope({super.key, required this.builder});

  final WidgetBuilder builder;

  /// Der nächstgelegene Refresh-Controller, oder `null`, wenn kein
  /// [PageRefreshScope] in der Vorfahrenkette liegt.
  static PageRefreshController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_PageRefreshInherited>()
        ?.controller;
  }

  @override
  State<PageRefreshScope> createState() => _PageRefreshScopeState();
}

/// Auslöser zum Zurücksetzen der umgebenden Seite.
class PageRefreshController {
  const PageRefreshController(this.refresh);

  final VoidCallback refresh;
}

class _PageRefreshScopeState extends State<PageRefreshScope> {
  // Bei jeder Erhöhung erhält der KeyedSubtree einen neuen Schlüssel, wodurch
  // der gesamte Teilbaum verworfen und frisch aufgebaut wird.
  int _generation = 0;

  late final PageRefreshController _controller = PageRefreshController(
    () => setState(() => _generation++),
  );

  @override
  Widget build(BuildContext context) {
    return _PageRefreshInherited(
      controller: _controller,
      generation: _generation,
      child: KeyedSubtree(
        key: ValueKey(_generation),
        child: Builder(builder: widget.builder),
      ),
    );
  }
}

class _PageRefreshInherited extends InheritedWidget {
  const _PageRefreshInherited({
    required this.controller,
    required this.generation,
    required super.child,
  });

  final PageRefreshController controller;
  final int generation;

  @override
  bool updateShouldNotify(_PageRefreshInherited oldWidget) =>
      generation != oldWidget.generation;
}

/// AppBar-Aktion, die die umgebende Seite über den [PageRefreshScope] in ihren
/// Anfangszustand zurücksetzt. Tut nichts, wenn kein Scope vorhanden ist.
class PageRefreshButton extends StatelessWidget {
  const PageRefreshButton({super.key, this.tooltip = 'Seite neu laden'});

  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final controller = PageRefreshScope.maybeOf(context);
    return IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: tooltip,
      onPressed: controller?.refresh,
    );
  }
}
