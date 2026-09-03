import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prüft, wie `scripts/versionspruefung.ps1` das Flutter-SDK auflöst.
///
/// Die Auflösung ist der Punkt, an dem die Prüfkette in einem frischen Klon
/// scheiterte, obwohl nichts fehlte: `.fvm/flutter_sdk` ist gitignored, liegt
/// also nach `git clone` und in jedem neuen Worktree nicht vor — das SDK selbst
/// aber liegt auf einem Rechner, der hier schon gearbeitet hat, längst im
/// FVM-Cache. Die Prüfung fiel deshalb auf das Flutter aus dem PATH zurück und
/// brach aus reinen Umgebungsgründen ab. Wer die Kette regelmäßig ohne Defekt
/// rot sieht, lernt das Falsche: rote Schritte wegzuerklären.
///
/// Getestet wird an einem Wegwerf-Repo im Temp-Verzeichnis: Im Frontend-Modus
/// liest das Skript nur `.github/workflows/ci.yml`,
/// `Automation_App_Frontend/.fvmrc` und das SDK selbst, und die lassen sich
/// vollständig nachbauen. Nur so sind die interessanten Fälle überhaupt
/// herstellbar — „Junction fehlt" ist im Arbeitsverzeichnis dessen, der den
/// Test fährt, nicht erreichbar, ohne sie ihm wegzunehmen.
///
/// Die SDKs sind Attrappen: eine `flutter.bat`, die eine Versionszeile ausgibt.
/// Das genügt, weil das Skript die Fassung nie aus dem Pfad ableitet, sondern
/// immer `flutter --version` fragt — genau diese Ehrlichkeit soll erhalten
/// bleiben.
void main() {
  final skript = File('../scripts/versionspruefung.ps1');

  group(
    'Auflösung des Flutter-SDK',
    () {
      late Directory tmp;

      setUp(() {
        tmp = Directory.systemTemp.createTempSync('versionspruefung');
        legeTestrepoAn(tmp, skript);
      });

      tearDown(() => tmp.deleteSync(recursive: true));

      test('nimmt die gepinnte Fassung aus FVM_CACHE_PATH', () async {
        final cache = Directory('${tmp.path}\\cache');
        final bin = legeSdkAn(cache, testfassung);

        final lauf = await pruefe(tmp, cache: cache);

        expect(
          lauf.exitCode,
          0,
          reason: 'Das SDK lag im Cache:\n${protokoll(lauf)}',
        );
        expect(alsPfad(lauf.stdout), alsPfad(bin.path));
      });

      test('nimmt sie ohne FVM_CACHE_PATH aus ~/fvm', () async {
        final heim = Directory('${tmp.path}\\heim');
        final bin = legeSdkAn(Directory('${heim.path}\\fvm'), testfassung);

        final lauf = await pruefe(tmp, heim: heim);

        expect(
          lauf.exitCode,
          0,
          reason: 'Das SDK lag unter ~/fvm:\n${protokoll(lauf)}',
        );
        expect(alsPfad(lauf.stdout), alsPfad(bin.path));
      });

      test(
        'bricht mit der gewohnten Meldung ab, wenn sie im Cache fehlt',
        () async {
          // Ein Flutter im PATH, das die falsche Fassung meldet: der Zustand, den
          // ein wirklich frischer Rechner erzeugt. Ohne diese Attrappe hinge das
          // Ergebnis daran, was auf dem Rechner des Prüfenden installiert ist.
          final ausDemPfad = legeSdkAn(Directory('${tmp.path}\\pfad'), '3.0.0');

          final lauf = await pruefe(
            tmp,
            cache: Directory('${tmp.path}\\leer'),
            zusatzPfad: ausDemPfad,
          );

          expect(lauf.exitCode, 1, reason: protokoll(lauf));
          expect(
            protokoll(lauf),
            allOf(
              contains('Flutter 3.0.0 statt der gepinnten $testfassung'),
              contains("'fvm install $testfassung'"),
            ),
            reason:
                'Die Meldung bleibt wortgleich stehen: Auf einem wirklich '
                'frischen Rechner ist `fvm install` ein Download, und den soll '
                'ein prüfendes Skript nicht stillschweigend auslösen. Sie ist '
                'dann die richtige Antwort und nicht der Fehler.',
          );
        },
      );

      test('lässt der Junction den Vortritt vor dem Cache', () async {
        // Ein gewöhnliches Verzeichnis steht hier für die Junction: Das Skript
        // fragt `Test-Path .../flutter_sdk/bin/flutter.bat` und interessiert
        // sich nicht dafür, wie der Ordner dorthin kam.
        final junction = legeSdkAn(
          Directory('${tmp.path}\\Automation_App_Frontend\\.fvm'),
          testfassung,
          unter: 'flutter_sdk',
        );
        final cache = Directory('${tmp.path}\\cache');
        legeSdkAn(cache, testfassung);

        final lauf = await pruefe(tmp, cache: cache);

        expect(lauf.exitCode, 0, reason: protokoll(lauf));
        expect(
          alsPfad(lauf.stdout),
          alsPfad(junction.path),
          reason:
              'Wer `fvm use` gefahren ist, hat sich für dieses SDK entschieden '
              '— auch wenn im Cache dieselbe Fassung liegt.',
        );
      });

      test('nimmt ohne .fvmrc die Pinnung aus ci.yml', () async {
        File('${tmp.path}\\Automation_App_Frontend\\.fvmrc').deleteSync();
        final cache = Directory('${tmp.path}\\cache');
        final bin = legeSdkAn(cache, testfassung);

        final lauf = await pruefe(tmp, cache: cache);

        expect(
          lauf.exitCode,
          0,
          reason:
              'Ohne .fvmrc bleibt die Pinnung aus ci.yml — daran am Cache '
              'vorbeizulaufen, wäre genau der Rückfall auf den PATH, den '
              'diese Auflösung abstellt.\n${protokoll(lauf)}',
        );
        expect(alsPfad(lauf.stdout), alsPfad(bin.path));
      });

      test(
        'hält an, wenn .fvmrc und FLUTTER_VERSION auseinanderlaufen',
        () async {
          File(
            '${tmp.path}\\Automation_App_Frontend\\.fvmrc',
          ).writeAsStringSync('{ "flutter": "1.2.3" }');
          final cache = Directory('${tmp.path}\\cache');
          legeSdkAn(cache, '1.2.3');

          final lauf = await pruefe(tmp, cache: cache);

          expect(lauf.exitCode, 1, reason: protokoll(lauf));
          expect(
            protokoll(lauf),
            contains('.fvmrc nennt Flutter 1.2.3, ci.yml FLUTTER_VERSION'),
            reason:
                'Der Cache-Weg löst nach .fvmrc auf, die CI prüft nach '
                'FLUTTER_VERSION. Laufen die beiden auseinander, fährt die Kette '
                'ein anderes SDK als die CI — der Zustand, den dieses Skript '
                'verhindert.',
          );
        },
      );

      test('meldet nicht grün, wenn ci.yml fehlt', () async {
        File('${tmp.path}\\.github\\workflows\\ci.yml').deleteSync();
        final cache = Directory('${tmp.path}\\cache');
        legeSdkAn(cache, testfassung);

        final lauf = await pruefe(tmp, cache: cache);

        expect(
          lauf.exitCode,
          1,
          reason:
              'Ohne die Pinnung hat kein Vergleich stattgefunden. `Get-Content` '
              'auf einen fehlenden Pfad bricht nicht ab: Das Skript lief '
              r'darüber hinweg, setzte kein $fehler und endete mit 0 — '
              'check.ps1 sah einen bestandenen Versionsvergleich, den es nie '
              'gab. Ein Wächter, der bei eigener Störung grün meldet, ist '
              'schlimmer als keiner.\n${protokoll(lauf)}',
        );
        expect(protokoll(lauf), contains('FLUTTER_VERSION'));
      });
    },
    skip: Platform.isWindows
        ? null
        : 'Die Prüfkette ist ein PowerShell-Skript.',
  );

  /// Die Skripte, die Flutter aufrufen, muessen es ueber diese Aufloesung tun.
  ///
  /// Der Fehler, den dieser Test festhaelt (03.09.2026): `build-package.ps1`
  /// rief blankes `flutter`. In der CI ist das die gepinnte Fassung —
  /// `flutter-action` installiert sie und legt sie in den PATH —, auf einem
  /// Entwicklerrechner mit fvm aber irgendeine. Das Skript baute das
  /// auslieferbare Paket also aus einer anderen Toolchain als die, gegen die
  /// geprueft wurde, und schrieb dabei stillschweigend `pubspec.lock` um.
  /// Beides fiel niemandem auf, weil in der CI beide Wege zusammenfallen:
  /// Genau darum braucht die Regel einen Test und keinen Hinweis.
  test('kein Skript ruft blankes flutter oder dart', () {
    // `versionspruefung.ps1` selbst darf: Es *ist* die Aufloesung und faellt
    // bewusst auf den PATH zurueck, wenn kein FVM-SDK vorliegt.
    const ausgenommen = {'versionspruefung.ps1'};
    // Nur der Befehlsname als **Anweisung** zaehlt: am Zeilenanfang (auch
    // eingerueckt) oder hinter `&`/`|`. In Kommentaren und Fehlermeldungen
    // steht „flutter" staendig, und das ist richtig so — die beginnen mit `#`
    // oder tragen den Namen mitten im Satz. Die Einrueckung war beim ersten
    // Anlauf vergessen, und damit liess der Waechter genau die Zeile durch,
    // um die es geht (`    flutter pub get`).
    final blank = RegExp(
      r'(?:^[ \t]*|[&|][ \t]*)(flutter|dart)[ \t]+(?!--version)\S',
      multiLine: true,
    );

    final verstoesse = <String>[];
    for (final datei in Directory('../scripts').listSync().whereType<File>()) {
      final name = datei.uri.pathSegments.last;
      if (!name.endsWith('.ps1') || ausgenommen.contains(name)) continue;
      for (final treffer in blank.allMatches(datei.readAsStringSync())) {
        verstoesse.add('$name: ${treffer.group(0)!.trim()}');
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Diese Aufrufe nehmen das Flutter/Dart aus dem PATH statt der '
          'gepinnten Fassung. Richtig ist der Weg von check.ps1: den Pfad '
          'ueber `versionspruefung.ps1 -NurFrontend` aufloesen und den '
          'aufgeloesten Befehl mit `&` aufrufen. Der Rueckfall auf den PATH '
          'steckt schon darin — er gilt in der CI, wo das PATH-Flutter die '
          'gepinnte Fassung ist.',
    );
  });
}

/// Die Fassung, auf die die Wegwerf-Repos gepinnt werden. Bewusst eine, die es
/// nicht gibt: So kann kein echtes SDK auf dem Rechner das Ergebnis färben.
const String testfassung = '9.9.9';

/// Legt unter [wurzel] gerade so viel Repo an, wie `versionspruefung.ps1` im
/// Frontend-Modus liest — und kopiert das Skript an seinen Platz, damit dessen
/// `$wurzel` (der Ordner über `scripts/`) hier landet und nicht im echten Repo.
void legeTestrepoAn(Directory wurzel, File skript) {
  Directory('${wurzel.path}\\scripts').createSync(recursive: true);
  skript.copySync('${wurzel.path}\\scripts\\versionspruefung.ps1');

  Directory('${wurzel.path}\\.github\\workflows').createSync(recursive: true);
  File(
    '${wurzel.path}\\.github\\workflows\\ci.yml',
  ).writeAsStringSync('env:\n  FLUTTER_VERSION: "$testfassung"\n');

  Directory('${wurzel.path}\\Automation_App_Frontend').createSync();
  File(
    '${wurzel.path}\\Automation_App_Frontend\\.fvmrc',
  ).writeAsStringSync('{ "flutter": "$testfassung" }');
}

/// Legt eine SDK-Attrappe an, die [fassung] meldet, und gibt deren
/// bin-Verzeichnis zurück. [unter] ist der Ordner unterhalb von [cache]; ohne
/// Angabe die FVM-Ablage `versions/<Fassung>`.
Directory legeSdkAn(Directory cache, String fassung, {String? unter}) {
  final bin = Directory('${cache.path}\\${unter ?? 'versions\\$fassung'}\\bin');
  bin.createSync(recursive: true);
  File('${bin.path}\\flutter.bat').writeAsStringSync(
    '@echo off\r\n'
    'echo Flutter $fassung - channel stable - '
    'https://github.com/flutter/flutter.git\r\n',
  );
  return bin;
}

/// Fährt die Prüfung im Wegwerf-Repo [wurzel], nur die Frontend-Hälfte.
///
/// [cache] setzt `FVM_CACHE_PATH`; ohne Angabe bleibt es leer, dann zählt
/// `$HOME` — und das folgt unter Windows `USERPROFILE`. [heim] verlegt eben
/// dieses `$HOME`, ohne Angabe auf einen leeren Ordner, damit kein echtes
/// `~/fvm` hineinspielt. [zusatzPfad] kommt vor den PATH und bestimmt so,
/// welches `flutter` das Skript findet, wenn es kein SDK aufgelöst hat.
Future<ProcessResult> pruefe(
  Directory wurzel, {
  Directory? cache,
  Directory? heim,
  Directory? zusatzPfad,
}) {
  final pfadVorne = zusatzPfad == null ? '' : '${zusatzPfad.path};';
  return Process.run(
    'powershell',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      '${wurzel.path}\\scripts\\versionspruefung.ps1',
      '-NurFrontend',
    ],
    environment: {
      'FVM_CACHE_PATH': cache?.path ?? '',
      'USERPROFILE': (heim ?? Directory('${wurzel.path}\\ohne-heim')).path,
      'PATH': '$pfadVorne${Platform.environment['PATH']}',
    },
  );
}

/// Beide Ströme zusammen — die Meldung eines fehlgeschlagenen `expect`.
String protokoll(ProcessResult lauf) => '${lauf.stdout}${lauf.stderr}';

/// Vergleichsform für Pfade. Zwei Eigenheiten sind wegzurechnen, sonst
/// vergleicht der Test Schreibweisen statt Verzeichnisse:
///
/// - Das Skript setzt Pfade mit `Join-Path` aus Stücken mit Schrägstrich
///   zusammen und liefert deshalb gemischte Trenner.
/// - `Directory.systemTemp` liefert unter Windows die 8.3-Kurzform
///   (`ROMAN~1.AHM`), PowerShells `$PSScriptRoot` die lange. Beide Seiten
///   werden deshalb aufgelöst, soweit es den Ordner gibt.
String alsPfad(Object? roh) {
  final text = '$roh'.trim().replaceAll('/', r'\');
  final ordner = Directory(text);
  final voll = ordner.existsSync() ? ordner.resolveSymbolicLinksSync() : text;
  return voll.toLowerCase();
}
