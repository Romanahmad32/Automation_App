/// Feste Tab-Indizes der Sidebar-Navigation — die eine Stelle, die bei einer
/// Umsortierung der Routen in `AppShellPage`/`AppSidebar` mitzupflegen ist.
/// Navigationssprünge (`AutoTabsRouter.setActiveIndex`) verwenden diese
/// Konstanten statt pro Feature hart kodierter Zahlen.
class AppTabIndex {
  /// Index 0 ist zugleich der Start-Tab: Was hier steht, sieht der Anwalt
  /// unmittelbar nach dem Öffnen der App.
  static const int dashboard = 0;
  static const int vorgangStarten = 1;
  static const int postfach = 2;
  static const int wordAutomation = 3;
  static const int vorlagenVerwalten = 4;
  static const int mandanten = 5;
  static const int register = 6;
  static const int vorgaenge = 7;
  static const int einstellungen = 8;
}
