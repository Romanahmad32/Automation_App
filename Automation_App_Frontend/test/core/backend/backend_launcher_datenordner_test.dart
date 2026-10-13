import 'dart:async';
import 'dart:io';

import 'package:automation_app/core/backend/backend_gesundheit.dart';
import 'package:automation_app/core/backend/backend_health_probe.dart';
import 'package:automation_app/core/backend/backend_launcher.dart';
import 'package:automation_app/core/backend/backend_start_ergebnis.dart';
import 'package:flutter_test/flutter_test.dart';

/// Antwortet der Reihe nach; die letzte Antwort bleibt stehen.
class FolgeBackendHealthProbe extends BackendHealthProbe {
  FolgeBackendHealthProbe(this.antworten);

  final List<BackendGesundheit?> antworten;
  int _aufrufe = 0;

  @override
  Future<BackendGesundheit?> gesundheitWennBereit({
    Duration zeitlimit = const Duration(seconds: 2),
  }) async {
    final index = _aufrufe < antworten.length ? _aufrufe : antworten.length - 1;
    _aufrufe++;
    return antworten[index];
  }
}

/// Ein Kindprozess, der nie endet und merkt, ob er beendet wurde.
class AttrappenProzess implements Process {
  bool beendet = false;

  @override
  Future<int> get exitCode => Completer<int>().future;

  @override
  Stream<List<int>> get stdout => const Stream.empty();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  int get pid => 1;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    beendet = true;
    return true;
  }
}

void main() {
  late Directory ordner;
  late File exe;
  var gestartet = 0;
  final prozess = AttrappenProzess();

  Future<Process> starter(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    gestartet++;
    return prozess;
  }

  BackendLauncher launcher(
    Map<String, String> umgebung, {
    BackendHealthProbe? probe,
  }) => BackendLauncher(
    probe: probe ?? FolgeBackendHealthProbe([null]),
    testmodusErwartet: true,
    umgebung: {BackendLauncher.pfadUmgebungsvariable: exe.path, ...umgebung},
    prozessStarter: starter,
  );

  setUp(() {
    gestartet = 0;
    prozess.beendet = false;
    ordner = Directory.systemTemp.createTempSync('launcher_test');
    exe = File('${ordner.path}${Platform.pathSeparator}dienst.exe')
      ..writeAsStringSync('');
  });

  tearDown(() => ordner.deleteSync(recursive: true));

  group('BackendLauncher im Testmodus: Datenordner', () {
    test('startet ohne Datenordner keinen Dienst', () async {
      final ergebnis = await launcher({}).starten();

      expect(gestartet, 0);
      expect(ergebnis.status, BackendStartStatus.fehlgeschlagen);
      expect(ergebnis.meldung, contains('scripts/e2e-start.ps1'));
    });

    test('startet bei leerem Datenordner keinen Dienst', () async {
      final ergebnis = await launcher({'Datenordner': '  '}).starten();

      expect(gestartet, 0);
      expect(ergebnis.status, BackendStartStatus.fehlgeschlagen);
    });

    test('startet bei relativem Datenordner keinen Dienst', () async {
      final ergebnis = await launcher({'Datenordner': 'daten'}).starten();

      expect(gestartet, 0);
      expect(ergebnis.status, BackendStartStatus.fehlgeschlagen);
    });

    test('die Argumente tragen Testmodus und Datenordner', () {
      final daten = '${ordner.path}${Platform.pathSeparator}daten';

      final argumente = launcher({'Datenordner': daten}).startArgumente();

      expect(argumente, containsAllInOrder(['--environment', 'E2E']));
      expect(argumente, contains('--Simulation:Testmodus=true'));
      expect(argumente, containsAllInOrder(['--Datenordner', daten]));
    });

    test('ohne Testmodus bleiben die Argumente unverändert', () {
      final argumente = BackendLauncher(
        testmodusErwartet: false,
        umgebung: const {},
      ).startArgumente();

      expect(argumente, isNot(contains('--Datenordner')));
      expect(argumente, isNot(contains('--Simulation:Testmodus=true')));
    });

    test('beendet einen selbst gestarteten Dienst ohne Testmodus', () async {
      final daten = '${ordner.path}${Platform.pathSeparator}daten';
      final probe = FolgeBackendHealthProbe([
        null,
        const BackendGesundheit(version: '1.0.0', testmodus: false),
      ]);

      final ergebnis = await launcher({
        'Datenordner': daten,
      }, probe: probe).starten();

      expect(gestartet, 1);
      expect(prozess.beendet, isTrue);
      expect(ergebnis.status, BackendStartStatus.fehlgeschlagen);
    });

    test('behält einen selbst gestarteten Dienst mit Testmodus', () async {
      final daten = '${ordner.path}${Platform.pathSeparator}daten';
      final probe = FolgeBackendHealthProbe([
        null,
        const BackendGesundheit(version: '1.0.0', testmodus: true),
      ]);

      final ergebnis = await launcher({
        'Datenordner': daten,
      }, probe: probe).starten();

      expect(prozess.beendet, isFalse);
      expect(ergebnis.status, BackendStartStatus.selbstGestartet);
    });
  });
}
