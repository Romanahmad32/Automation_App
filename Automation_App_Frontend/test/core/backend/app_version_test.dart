import 'package:automation_app/core/backend/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion', () {
    test('zeigt nur die Versionsnummer, nicht den Commit-Anhang', () {
      // Das SDK hängt an die InformationalVersion den Commit an, aus dem
      // gebaut wurde. In der Seitenleiste hat er nichts zu suchen — dort steht
      // die Zahl, die auch in "Apps & Features" und im Release-Tag steht.
      expect(const AppVersion('1.0.0+34888af').anzeige, '1.0.0');
    });

    test('kommt auch ohne Anhang zurecht', () {
      expect(const AppVersion('1.0.0').anzeige, '1.0.0');
    });
  });
}
