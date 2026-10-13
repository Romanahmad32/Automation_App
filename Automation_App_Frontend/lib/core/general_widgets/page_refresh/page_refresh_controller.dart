import 'package:material_ui/material_ui.dart';

/// Auslöser zum Zurücksetzen der umgebenden Seite.
///
/// Liegt in einer eigenen Datei, damit [PageRefreshInherited] und
/// [PageRefreshScope] ihn beide verwenden können, ohne sich gegenseitig zu
/// importieren.
class PageRefreshController {
  const PageRefreshController(this.refresh);

  final VoidCallback refresh;
}
