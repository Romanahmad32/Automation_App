// Marionette-Konfiguration für die E2E-Abnahme (siehe README.md in diesem Ordner).
//
// marionette_flutter 0.7.0 erkennt Bedienelemente über die Material-Typen aus
// `package:flutter/material.dart`. Die App nutzt `material_ui`, das sind andere
// Klassen — ohne diese Zuordnung fände `get_interactive_elements` fast nichts.
import 'package:automation_app/core/general_widgets/drawer/side_bar_item.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:material_ui/material_ui.dart';

/// Die Konfiguration für `MarionetteBinding.ensureInitialized`.
const marionetteKonfiguration = MarionetteConfiguration(
  isInteractiveElement: istBedienelement,
  extractText: beschriftungFuerMarionette,
);

/// Erkennt die material_ui-Bedienelemente als interaktiv.
///
/// Das Paket ruft dies nur für Widgets auf, die es nicht selbst kennt. Ein
/// Treffer hier beendet die Traversierung nicht (nur `shouldStopAtElement`
/// tut das, und das bleibt unberührt): Kinder wie der Text eines Knopfes
/// werden weiter gefunden.
bool istBedienelement(Element element) {
  return switch (element.widget) {
    IconButton() ||
    TextField() ||
    TextFormField() ||
    ButtonStyleButton() ||
    FloatingActionButton() ||
    Checkbox() ||
    CheckboxListTile() ||
    Switch() ||
    SwitchListTile() ||
    Radio() ||
    RadioListTile() ||
    Slider() ||
    DropdownButton() ||
    DropdownButtonFormField() ||
    DropdownMenu() ||
    PopupMenuButton() ||
    SegmentedButton() ||
    ActionChip() ||
    FilterChip() ||
    ChoiceChip() ||
    InputChip() ||
    InkWell() => true,
    ListTile(:final onTap) => onTap != null,
    _ => false,
  };
}

/// Macht Bedienelemente ohne sichtbaren Text über `text` erreichbar.
///
/// Marionette liest Text nur aus `Text`/`RichText` und den Feldern des alten
/// Material. Die Seitenleiste zeigt eingeklappt nur Symbole, die Symbolknöpfe
/// (Löschen, Bearbeiten, Vollmacht …) tragen ihre Beschriftung nur im Tooltip,
/// und ein material_ui-`TextField` bliebe ohne Wert und Label unauffindbar —
/// ohne diese Zuordnung blieben sie nur über Koordinaten erreichbar, und die
/// fragt die Marionette-Sperre jedes Mal nach. Bei einem Textfeld gilt der
/// eingegebene Text, bei leerem Feld Label oder Hinweis.
/// Gleichnamige Knöpfe in einer Liste trennt `ancestor_keys` (z. B. der
/// `ValueKey(referenz)` einer Vorgangskachel).
String? beschriftungFuerMarionette(Element element) {
  final widget = element.widget;
  if (widget is SidebarItem) return widget.label;
  if (widget is IconButton) return widget.tooltip;
  if (widget is Tooltip) return widget.message;
  if (widget is TextField) {
    final eingabe = widget.controller?.text;
    if (eingabe != null && eingabe.isNotEmpty) return eingabe;
    return widget.decoration?.labelText ?? widget.decoration?.hintText;
  }
  return null;
}
