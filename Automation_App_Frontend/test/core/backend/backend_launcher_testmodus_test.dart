import 'package:automation_app/core/backend/backend_endpoint.dart';
import 'package:automation_app/core/backend/backend_gesundheit.dart';
import 'package:automation_app/core/backend/backend_launcher.dart';
import 'package:automation_app/core/backend/backend_start_ergebnis.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backend_launcher_test.dart';

void main() {
  group('BackendLauncher im Testmodus', () {
    test('übernimmt keinen Dienst, der keinen Testmodus meldet', () async {
      final launcher = BackendLauncher(
        probe: const FesteBackendHealthProbe(bereit: true),
        testmodusErwartet: true,
      );

      final ergebnis = await launcher.starten();

      // Sonst hinge der Testlauf an der Datenbank der installierten Anwendung
      // und würde echt versenden und drucken.
      expect(ergebnis.status, BackendStartStatus.fehlgeschlagen);
      expect(ergebnis.erfolgreich, isFalse);
    });

    test('nennt in der Meldung Adresse und Startskript', () async {
      final launcher = BackendLauncher(
        probe: const FesteBackendHealthProbe(bereit: true),
        testmodusErwartet: true,
      );

      final ergebnis = await launcher.starten();

      expect(ergebnis.meldung, contains(BackendEndpoint.adresse));
      expect(ergebnis.meldung, contains('scripts/e2e-start.ps1'));
    });

    test('übernimmt einen Dienst, der Testmodus meldet', () async {
      final launcher = BackendLauncher(
        probe: const FesteBackendHealthProbe(bereit: true, testmodus: true),
        testmodusErwartet: true,
      );

      final ergebnis = await launcher.starten();

      expect(ergebnis.status, BackendStartStatus.bereitsGestartet);
      expect(ergebnis.erfolgreich, isTrue);
    });

    test('ohne Erwartung bleibt alles wie bisher', () async {
      final launcher = BackendLauncher(
        probe: const FesteBackendHealthProbe(bereit: true),
        testmodusErwartet: false,
      );

      final ergebnis = await launcher.starten();

      expect(ergebnis.status, BackendStartStatus.bereitsGestartet);
    });

    test('startet den Dienst im Testmodus in der Umgebung E2E', () {
      final mit = BackendLauncher(testmodusErwartet: true).startArgumente();
      final ohne = BackendLauncher(testmodusErwartet: false).startArgumente();

      expect(mit, containsAllInOrder(['--environment', 'E2E']));
      expect(ohne, isNot(contains('--environment')));
      expect(ohne, contains('--parent-pid'));
    });
  });

  group('BackendGesundheit.ausKoerper', () {
    test('liest Version und Testmodus', () {
      final g = BackendGesundheit.ausKoerper(
        '{"status":"bereit","version":"1.3.0","testmodus":true}',
      );

      expect(g.version, '1.3.0');
      expect(g.testmodus, isTrue);
    });

    test('fehlendes Feld testmodus heißt kein Testmodus', () {
      // Ein älterer Dienst kennt das Feld nicht; er darf nie als Testdienst
      // gelten.
      final g = BackendGesundheit.ausKoerper(
        '{"status":"bereit","version":"1.2.0"}',
      );

      expect(g.testmodus, isFalse);
      expect(g.version, '1.2.0');
    });

    test('unlesbarer Körper heißt kein Testmodus', () {
      final g = BackendGesundheit.ausKoerper('kein json');

      expect(g.testmodus, isFalse);
    });

    test('testmodus, das kein bool ist, zählt nicht', () {
      final g = BackendGesundheit.ausKoerper('{"testmodus":"true"}');

      expect(g.testmodus, isFalse);
    });
  });
}
