// Einstiegspunkt NUR für E2E-Abnahmetests per Marionette MCP (siehe README.md
// in diesem Ordner).
//
// Die Datei liegt bewusst außerhalb von `lib/`: Ein normaler Release-Build
// (`flutter build windows`) startet `lib/main.dart` und zieht diese Datei nie
// ein; das Paket `marionette_flutter` ist nur eine dev_dependency. Läge der
// Einstieg in `lib/`, könnte er versehentlich in die Auslieferung geraten und
// der App eine Fernsteuerung für KI-Agenten öffnen.
import 'package:automation_app/core/general_widgets/drawer/side_bar_item.dart';
import 'package:automation_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

void main() {
  // Muss vor allem anderen laufen: Flutter erlaubt nur ein Binding. Das
  // `WidgetsFlutterBinding.ensureInitialized()` in `app.main()` liefert danach
  // das vorhandene Marionette-Binding zurück.
  MarionetteBinding.ensureInitialized(
    const MarionetteConfiguration(extractText: beschriftungFuerMarionette),
  );
  app.main();
}

/// Macht Bedienelemente ohne sichtbaren Text über `text` erreichbar.
///
/// Marionette liest Text nur aus `Text`/`RichText`/Eingabefeldern und
/// vergleicht exakt. Die Seitenleiste zeigt eingeklappt nur Symbole, und die
/// Symbolknöpfe (Löschen, Bearbeiten, Vollmacht …) tragen ihre Beschriftung
/// nur im Tooltip — ohne diese Zuordnung blieben sie nur über Koordinaten
/// erreichbar, und die fragt die Marionette-Sperre jedes Mal nach.
/// Gleichnamige Knöpfe in einer Liste trennt `ancestor_keys` (z. B. der
/// `ValueKey(referenz)` einer Vorgangskachel).
String? beschriftungFuerMarionette(Element element) {
  final widget = element.widget;
  if (widget is SidebarItem) return widget.label;
  if (widget is IconButton) return widget.tooltip;
  return null;
}
