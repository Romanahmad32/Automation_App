import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:automation_app/core/backend/app_version.dart';
import 'package:automation_app/core/backend/backend_endpoint.dart';
import 'package:automation_app/core/backend/backend_health_probe.dart';
import 'package:automation_app/core/backend/backend_start_ergebnis.dart';
import 'package:flutter/foundation.dart';

/// Startet den lokalen Dienst als Kindprozess und wartet, bis er bereit ist.
///
/// Damit erfüllt die Anwendung das Auslieferungsziel: der Anwalt klickt ein
/// Symbol, nicht zwei. Der Dienst liegt im ausgelieferten Build neben der
/// Anwendung unter `backend\AutomationService.exe`.
///
/// Läuft bereits ein Dienst auf [BackendEndpoint.adresse], wird dieser
/// verwendet und keiner gestartet — sonst würde beim Entwickeln (`dotnet run`
/// in einem Terminal, `flutter run` im anderen) eine zweite Instanz auf
/// derselben Datenbank hochkommen.
///
/// **Beenden** übernimmt der Dienst selbst: er bekommt die Prozess-ID der
/// Anwendung als `--parent-pid` und fährt herunter, sobald diese endet (siehe
/// `ParentProcessWatchdog` im Backend). Das ist robuster als ein Abschuss von
/// hier aus, weil es auch bei einem Absturz der Anwendung greift — und es ist
/// ein *geordnetes* Herunterfahren, bei dem die PDF-Konvertierung ihre
/// Word-Instanz freigibt.
class BackendLauncher {
  BackendLauncher({
    this.probe = const BackendHealthProbe(),
    this.testmodusErwartet = BackendEndpoint.testmodusErwartet,
    Map<String, String>? umgebung,
    this.prozessStarter = Process.start,
  }) : umgebung = umgebung ?? Platform.environment;

  /// Die Umgebungsvariablen, aus denen `Datenordner` und der Dienstpfad
  /// gelesen werden — ein Parameter, damit Tests sie vorgeben können.
  final Map<String, String> umgebung;

  /// Startet den Kindprozess; im Test durch eine Attrappe ersetzbar.
  final Future<Process> Function(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  })
  prozessStarter;

  final BackendHealthProbe probe;

  /// Im E2E-Testmodus (`AUTOMATION_TESTMODUS`) wird nur ein Dienst benutzt,
  /// der selbst „Testmodus“ meldet — ob übernommen oder selbst gestartet.
  /// Ein Parameter statt der Konstante, weil sich eine Übersetzungskonstante
  /// im Test nicht umschalten lässt.
  final bool testmodusErwartet;

  /// Großzügig: der erste Start migriert die Datenbank und wärmt Word vor.
  static const Duration startFrist = Duration(seconds: 90);
  static const Duration pollAbstand = Duration(milliseconds: 250);

  static const String exeName = 'AutomationService.exe';
  static const String exeUnterordner = 'backend';

  /// Überschreibt den Suchpfad — damit lässt sich der ausgelieferte Ablauf
  /// testen, ohne die Anwendung erst zu paketieren.
  static const String pfadUmgebungsvariable = 'AUTOMATION_BACKEND_EXE';

  /// Ringpuffer der letzten Ausgaben; im Fehlerfall die einzige Spur, warum
  /// der Dienst nicht hochkam.
  static const int protokollZeilen = 15;
  final List<String> _letzteAusgaben = [];

  Future<BackendStartErgebnis> starten() async {
    final laufende = await probe.gesundheitWennBereit();
    if (laufende != null) {
      if (testmodusErwartet && !laufende.testmodus) {
        return BackendStartErgebnis.fehlgeschlagen(keinTestmodusMeldung());
      }
      return BackendStartErgebnis.bereitsGestartet(
        AppVersion(laufende.version),
      );
    }

    // Im Testmodus nur mit gesetztem, absolutem Datenordner starten: ohne ihn
    // käme der Dienst auf den echten Daten hoch, und das `kill()` nach
    // `/health` wäre zu spät — Datenbank und Sicherung wären schon angefasst.
    if (testmodusErwartet && datenordnerFuerTestmodus() == null) {
      return BackendStartErgebnis.fehlgeschlagen(keinDatenordnerMeldung());
    }

    final exe = backendExe(umgebung: umgebung);
    if (exe == null) {
      return BackendStartErgebnis.fehlgeschlagen(
        'Der lokale Dienst wurde nicht gefunden.\n\n'
        'Erwartet unter:\n${erwarteterPfad(umgebung: umgebung)}\n\n'
        'Beim Entwickeln wird der Dienst nicht mitgeliefert — dort bitte in '
        'AutomationService/AutomationService "dotnet run" starten.',
      );
    }

    final prozess = await prozessStarter(
      exe.path,
      startArgumente(),
      workingDirectory: exe.parent.path,
    );

    _lauscheAufAusgabe(prozess.stdout);
    _lauscheAufAusgabe(prozess.stderr);

    int? beendetMit;
    unawaited(prozess.exitCode.then((code) => beendetMit = code));

    final frist = DateTime.now().add(startFrist);
    while (DateTime.now().isBefore(frist)) {
      final gesundheit = await probe.gesundheitWennBereit();
      if (gesundheit != null) {
        if (testmodusErwartet && !gesundheit.testmodus) {
          prozess.kill();
          return BackendStartErgebnis.fehlgeschlagen(keinTestmodusMeldung());
        }
        return BackendStartErgebnis.selbstGestartet(
          AppVersion(gesundheit.version),
        );
      }
      final code = beendetMit;
      if (code != null) {
        return BackendStartErgebnis.fehlgeschlagen(
          'Der lokale Dienst hat sich beim Start sofort beendet '
          '(Rückgabewert $code).\n\n${_protokollAuszug()}',
        );
      }
      await Future<void>.delayed(pollAbstand);
    }

    prozess.kill();
    return BackendStartErgebnis.fehlgeschlagen(
      'Der lokale Dienst hat sich nicht innerhalb von '
      '${startFrist.inSeconds} Sekunden gemeldet '
      '(${BackendEndpoint.adresse}).\n\n${_protokollAuszug()}',
    );
  }

  /// Kommandozeile für den selbst gestarteten Dienst.
  List<String> startArgumente() => [
    // Ausdrücklich, obwohl es auch in appsettings.json steht: die
    // Kommandozeile schlägt eine etwaige ASPNETCORE_URLS-Variable der
    // Maschine, appsettings dagegen nicht.
    '--urls', BackendEndpoint.basisUrl,
    '--parent-pid', '$pid',
    // Der Testmodus braucht die Umgebung E2E. Testmodus und Datenordner stehen
    // zusätzlich auf der Kommandozeile: Der Dienst bricht bei einer
    // Fehlkonfiguration dann selbst ab, bevor er etwas anlegt.
    if (testmodusErwartet) ...[
      '--environment',
      'E2E',
      '--Simulation:Testmodus=true',
      '--Datenordner',
      datenordnerFuerTestmodus() ?? '',
    ],
  ];

  /// Der Datenordner aus der Umgebungsvariable `Datenordner`, oder `null`,
  /// wenn sie fehlt, leer oder kein absoluter Pfad ist.
  String? datenordnerFuerTestmodus() {
    final wert = umgebung['Datenordner'];
    if (wert == null || wert.trim().isEmpty) return null;
    return Directory(wert).isAbsolute ? wert : null;
  }

  /// Meldung, wenn im Testmodus kein brauchbarer Datenordner vorgegeben ist.
  static String keinDatenordnerMeldung() =>
      'Die Anwendung läuft im Testmodus, aber die Umgebungsvariable '
      'Datenordner fehlt oder ist kein absoluter Pfad. Der Dienst wird nicht '
      'gestartet, damit keine echten Daten berührt werden.\n\n'
      'Anwendung und Dienst bitte mit scripts/e2e-start.ps1 starten.';

  /// Meldung an den Anwender, wenn im Testmodus ein Dienst ohne Testmodus
  /// antwortet — er würde mit echten Daten arbeiten und echt versenden.
  static String keinTestmodusMeldung() =>
      'Die Anwendung läuft im Testmodus, der Dienst unter '
      '${BackendEndpoint.adresse} meldet aber keinen Testmodus. Er wird nicht '
      'verwendet, damit keine echten Daten berührt werden.\n\n'
      'Den Testdienst bitte mit scripts/e2e-start.ps1 starten.';

  /// Der ausgelieferte Dienst, oder `null`, wenn keiner danebenliegt.
  static File? backendExe({Map<String, String>? umgebung}) {
    final datei = File(erwarteterPfad(umgebung: umgebung));
    return datei.existsSync() ? datei : null;
  }

  static String erwarteterPfad({Map<String, String>? umgebung}) {
    final ueberschrieben =
        (umgebung ?? Platform.environment)[pfadUmgebungsvariable];
    if (ueberschrieben != null && ueberschrieben.isNotEmpty) {
      return ueberschrieben;
    }
    final anwendungsverzeichnis = File(Platform.resolvedExecutable).parent.path;
    final t = Platform.pathSeparator;
    return '$anwendungsverzeichnis$t$exeUnterordner$t$exeName';
  }

  /// Muss gelesen werden: bleibt die Pipe ungeleert, blockiert der Dienst,
  /// sobald der Puffer voll ist — er würde also mitten im Start stehenbleiben.
  void _lauscheAufAusgabe(Stream<List<int>> ausgabe) {
    ausgabe
        // Die Konsole liefert unter Windows nicht zwingend UTF-8; ein Umlaut
        // im Log darf den Start nicht mit einer Decoder-Exception abbrechen.
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((zeile) {
          if (_letzteAusgaben.length >= protokollZeilen) {
            _letzteAusgaben.removeAt(0);
          }
          _letzteAusgaben.add(zeile);
          if (kDebugMode) debugPrint('[Dienst] $zeile');
        }, onError: (Object _) {});
  }

  String _protokollAuszug() => _letzteAusgaben.isEmpty
      ? 'Der Dienst hat nichts ausgegeben.'
      : 'Letzte Ausgaben des Dienstes:\n${_letzteAusgaben.join('\n')}';
}
