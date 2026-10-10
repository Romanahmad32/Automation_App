// Einstiegspunkt NUR für E2E-Abnahmetests per Marionette MCP (siehe README.md
// in diesem Ordner).
//
// Die Datei liegt bewusst außerhalb von `lib/`: Ein normaler Release-Build
// (`flutter build windows`) startet `lib/main.dart` und zieht diese Datei nie
// ein; das Paket `marionette_flutter` ist nur eine dev_dependency. Läge der
// Einstieg in `lib/`, könnte er versehentlich in die Auslieferung geraten und
// der App eine Fernsteuerung für KI-Agenten öffnen.
import 'package:automation_app/main.dart' as app;
import 'package:marionette_flutter/marionette_flutter.dart';

void main() {
  // Muss vor allem anderen laufen: Flutter erlaubt nur ein Binding. Das
  // `WidgetsFlutterBinding.ensureInitialized()` in `app.main()` liefert danach
  // das vorhandene Marionette-Binding zurück.
  MarionetteBinding.ensureInitialized();
  app.main();
}
