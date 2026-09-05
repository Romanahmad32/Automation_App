import 'package:automation_app/features/word_automation/domain/entities/standard_schadenspositionen.dart';
import 'package:flutter/foundation.dart';

/// Der **ungespeicherte** Stand des Standardpositionen-Editors: die Zeilen, wie
/// sie gerade in den Feldern stehen, und ob einer ihrer Beträge beanstandet
/// ist.
///
/// Er gehört der Seite (`StandardpositionenSettingsView`) und nicht dem Editor,
/// weil der Speichern-Knopf seit der Umstellung auf die Kopfzeile **über** dem
/// Abschnitt sitzt, dessen Zeilen er speichert. Der Knopf muss also lesen
/// können, was unten getippt wurde — und ein Kind reicht seinem Elternteil
/// nichts nach oben. Dieselbe Bahn hält `MailboxAccessView` für ihre Signatur
/// vor: „Die Signatur gehört der Seite, nicht ihrem Abschnitt."
///
/// Warum nicht einfach der `StandardpositionenCubit`: Dessen Zustand ist der
/// **gespeicherte** Stand, und daran hängt mehr als der Knopf. Er steuert über
/// `StandNachziehen` das Nachziehen der Felder im Editor und über `geladen` den
/// `ValueKey` des Formulars in `wizard_step_schadensaufstellung.dart`. Liefe
/// jeder Tastendruck dort hindurch, baute sich die Schadensaufstellung des
/// Wizards beim Tippen neu auf und der Editor überschriebe sich seine eigenen
/// Felder — eine Rückkopplung, die der Entwurf hier gar nicht erst aufmacht.
class StandardpositionenEntwurf extends ChangeNotifier {
  List<StandardSchadensposition> _positionen = const [];
  bool _beanstandet = false;

  /// Die Zeilen des Editors, leere Bezeichnungen bereits heraus. Unveränderlich
  /// — geändert wird nur über [uebernimm], damit der Knopf keinen Stand sieht,
  /// von dem der Editor nichts weiß.
  List<StandardSchadensposition> get positionen => _positionen;

  /// Mindestens ein Betrag ist unlesbar oder negativ. Solange das gilt, bleibt
  /// der Speichern-Knopf gesperrt.
  bool get beanstandet => _beanstandet;

  /// Meldet den Stand des Editors — bei jeder Änderung an den Zeilen.
  ///
  /// [notifyListeners] läuft nur, wenn sich tatsächlich etwas geändert hat: Der
  /// Editor ruft das bei jedem Tastendruck, die Kopfzeile muss sich aber nur
  /// neu zeichnen, wenn ihr Knopf danach anders aussieht oder anders speichert.
  void uebernimm(
    List<StandardSchadensposition> positionen, {
    required bool beanstandet,
  }) {
    if (beanstandet == _beanstandet && listEquals(positionen, _positionen)) {
      return;
    }
    _positionen = List.unmodifiable(positionen);
    _beanstandet = beanstandet;
    notifyListeners();
  }
}
