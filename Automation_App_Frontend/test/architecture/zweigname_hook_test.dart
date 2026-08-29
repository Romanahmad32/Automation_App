import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prüft den Zweignamen-Hook (`.claude/hooks/zweigname.ps1`) an echten
/// Befehlszeilen — und seine Präfixliste gegen die des CI-Schritts.
///
/// Warum überhaupt ein Test für einen Hook: Er ist die einzige Stelle im Repo,
/// die einen Befehl anhält, *bevor* er läuft. Ein Wächter, der bei
/// Alltagsbefehlen anschlägt, wird abgeschaltet — und ist dann kein Wächter
/// mehr, sondern eine Datei. Genau das ist zweimal passiert: `git branch |
/// grep master` wurde blockiert, weil `\S+` auch die Pipe fing; danach
/// blockierte `git branch -a`, weil der Bindestrich in den Zeichenvorrat
/// gehört (`feature/zwei-namen`), aber nicht an dessen Anfang. Beide Male fand
/// es ein Mensch, der Befehle von Hand durchprobierte. Das ist die Arbeit, die
/// hier steht.
///
/// Die zweite Hälfte macht einen Kommentar ausführbar: Über `$erlaubt` stand
/// „Dieselbe Liste wie im CI-Schritt", während der CI-Schritt drei
/// Alternativen führte und der Hook zwei. Ein Satz, der sich selbst prüft,
/// kann nicht stillschweigend falsch werden.
///
/// Der Verhaltensteil startet je Fall einen PowerShell-Prozess (rund 400 ms)
/// und läuft nur unter Windows. Deshalb steht hier eine knappe Auswahl statt
/// jeder denkbaren Schreibweise: die Formen, mit denen ein Zweig entsteht, und
/// die Alltagsbefehle, die ihnen ähnlich sehen.
void main() {
  final hook = File('../.claude/hooks/zweigname.ps1');
  final ci = File('../.github/workflows/ci.yml');

  test('Hook und CI-Schritt lassen dieselben Präfixe zu', () {
    if (!hook.existsSync() || !ci.existsSync()) return;

    final imHook = RegExp(
      r"\$erlaubt = '\^\(([^)]+)\)/'",
    ).firstMatch(hook.readAsStringSync())?.group(1)?.split('|').toSet();

    final zeile = ci
        .readAsLinesSync()
        .where((z) => z.contains('feature/*'))
        .join();
    final imCi = RegExp(
      r'([a-z]+)/\*',
    ).allMatches(zeile).map((t) => t.group(1)!).toSet();

    expect(
      imHook,
      isNotNull,
      reason:
          'In .claude/hooks/zweigname.ps1 ist die Zeile `\$erlaubt = ...` '
          'nicht mehr zu finden. Wurde sie umbenannt, prüft dieser Test nichts '
          'mehr — dann gehört das Muster hier nachgezogen.',
    );
    expect(imCi, isNotEmpty, reason: 'Im CI-Schritt fehlt das `case`-Muster.');
    expect(
      imHook,
      imCi,
      reason:
          'Der Hook hält beim Anlegen an, der CI-Schritt am Pull Request — '
          'laufen die Listen auseinander, verbietet die eine Seite, was die '
          'andere erlaubt. dependabot/ ist der Fall, an dem es zuerst auffällt: '
          'Ohne den Eintrag hält der Hook an, was `gh pr checkout` bei einem '
          'Abhängigkeits-PR absetzt.',
    );
  });

  group(
    'der Hook hält genau die Zweiganlagen an',
    () {
      // (erwarteter Exit, Befehl) — 0 durchlassen, 2 anhalten.
      const faelle = <(int, String)>[
        (0, 'git branch | grep master'),
        (0, 'git branch > zweige.txt'),
        (0, 'git branch -a'),
        (0, 'git branch -d schnellfix'),
        (0, 'git checkout master'),
        (0, 'git commit -am "wip"'),
        (0, 'git checkout -b feature/zweignamen'),
        (0, 'git checkout -b "bugfix/in-anfuehrungszeichen"'),
        (0, 'git checkout -b feature/zwei-namen-mit-strich'),
        (0, 'git checkout -b dependabot/nuget/xunit-4.0.0 --track origin/x'),
        (2, 'git checkout -b schnellfix'),
        (2, 'git checkout -b Feature/GrossGeschrieben'),
        (2, 'git switch --create schnellfix'),
        (2, 'git branch -m schnellfix'),
        (2, 'git branch schnellfix'),
      ];

      for (final (erwartet, befehl) in faelle) {
        final was = erwartet == 0 ? 'lässt durch' : 'hält an';
        test('$was: $befehl', () async {
          final prozess = await Process.start('powershell', [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            hook.path,
          ]);
          prozess.stdin.write(
            jsonEncode({
              'tool_input': {'command': befehl},
            }),
          );
          await prozess.stdin.close();

          // Beide Ströme leeren, bevor auf das Ende gewartet wird: Ein volles
          // Rohr hält den Prozess sonst an und der Test läuft in die Zeitgrenze.
          final meldung = await prozess.stderr.transform(utf8.decoder).join();
          await prozess.stdout.drain<void>();

          expect(
            await prozess.exitCode,
            erwartet,
            reason: meldung.isEmpty
                ? 'Der Hook ließ den Befehl durch, obwohl er einen Zweig anlegt.'
                : 'Der Hook hielt an mit: ${meldung.split('\n').first}',
          );
        });
      }
    },
    skip: Platform.isWindows ? null : 'Der Hook ist ein PowerShell-Skript.',
  );
}
