import 'dart:io';

import 'package:automation_app/core/backend/backend_endpoint.dart';
import 'package:automation_app/core/backend/backend_health_probe.dart';
import 'package:automation_app/core/backend/backend_launcher.dart';
import 'package:automation_app/core/backend/backend_start_ergebnis.dart';
import 'package:flutter_test/flutter_test.dart';

/// Antwortet fest, ohne den Dienst wirklich zu befragen.
class FesteBackendHealthProbe extends BackendHealthProbe {
  const FesteBackendHealthProbe({required this.bereit, this.version = '1.2.3'});

  final bool bereit;
  final String version;

  @override
  Future<String?> versionWennBereit({
    Duration zeitlimit = const Duration(seconds: 2),
  }) async => bereit ? version : null;
}

void main() {
  group('BackendLauncher', () {
    test('startet keinen zweiten Dienst, wenn schon einer läuft', () async {
      final launcher = BackendLauncher(
        probe: const FesteBackendHealthProbe(bereit: true),
      );

      final ergebnis = await launcher.starten();

      // Beim Entwickeln läuft der Dienst per "dotnet run". Würde die Anwendung
      // trotzdem einen eigenen starten, kämen zwei Instanzen auf dieselbe
      // SQLite-Datei — und die zweite scheitert am belegten Port.
      expect(ergebnis.status, BackendStartStatus.bereitsGestartet);
      expect(ergebnis.erfolgreich, isTrue);
    });

    test('reicht die gemeldete Version durch', () async {
      final launcher = BackendLauncher(
        probe: const FesteBackendHealthProbe(
          bereit: true,
          version: '1.2.3+abc1234',
        ),
      );

      final ergebnis = await launcher.starten();

      // Die Seitenleiste zeigt daraus "v1.2.3". Kommt hier nichts an, steht
      // dort "unbekannt" — und die Frage "welchen Stand hat er?" bleibt offen.
      expect(ergebnis.version?.anzeige, '1.2.3');
      expect(ergebnis.version?.roh, '1.2.3+abc1234');
    });

    test('meldet einen verwertbaren Fehler, wenn der Dienst fehlt', () async {
      final launcher = BackendLauncher(
        probe: const FesteBackendHealthProbe(bereit: false),
      );

      final ergebnis = await launcher.starten();

      // Im Testlauf liegt neben der Testumgebung kein ausgelieferter Dienst.
      expect(ergebnis.status, BackendStartStatus.fehlgeschlagen);
      expect(ergebnis.erfolgreich, isFalse);
      // Die Meldung landet unverändert vor dem Anwender: sie muss den erwarteten
      // Pfad nennen, sonst ist sie im Ernstfall wertlos.
      expect(ergebnis.meldung, contains(BackendLauncher.exeName));
      expect(ergebnis.meldung, contains('dotnet run'));
    });

    test('sucht den Dienst neben der Anwendung im Unterordner "backend"', () {
      final pfad = BackendLauncher.erwarteterPfad();
      final t = Platform.pathSeparator;

      expect(
        pfad,
        endsWith(
          '$t${BackendLauncher.exeUnterordner}$t${BackendLauncher.exeName}',
        ),
      );
    });
  });

  group('BackendEndpoint', () {
    test('leitet alle Adressen aus Host und Port ab', () {
      // Der Sinn der Klasse: Port und Host stehen genau einmal im Code.
      expect(BackendEndpoint.basisUrl, 'http://${BackendEndpoint.adresse}');
      expect(BackendEndpoint.healthUrl, startsWith(BackendEndpoint.basisUrl));
      expect(
        BackendEndpoint.mailboxHubUrl,
        startsWith(BackendEndpoint.basisUrl),
      );
    });
  });
}
