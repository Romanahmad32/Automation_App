/// Feste Tab-Indizes der Sidebar-Navigation — die eine Stelle, die bei einer
/// Umsortierung der Routen in `AppShellPage`/`AppSidebar` mitzupflegen ist.
/// Navigationssprünge (`AutoTabsRouter.setActiveIndex`) verwenden diese
/// Konstanten statt pro Feature hart kodierter Zahlen.
class AppTabIndex {
  static const int vorgangStarten = 0;
  static const int postfach = 1;
  static const int wordAutomation = 2;
  static const int vorlagenVerwalten = 3;
  static const int mandanten = 4;
  static const int register = 5;
  static const int vorgaenge = 6;
  static const int einstellungen = 7;
}
