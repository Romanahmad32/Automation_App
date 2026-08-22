import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'doku_verweise.dart';

/// Erzwingt die gestufte Dokumentation, auf die sich ein Agent mit frischem
/// Kontext verlaesst: Wurzel-`CLAUDE.md` als Wegweiser, je eine `CLAUDE.md` pro
/// Teilbaum, je ein Steckbrief `FEATURE.md` pro Feature.
///
/// Diese Doku ist ein Vertrag wie der HTTP-Vertrag: sie steht neben dem Code,
/// nicht darin, und faellt deshalb geraeuschlos auseinander, sobald jemand ein
/// Feature umbenennt, eine Datei verschiebt oder ein neues Feature anlegt.
/// Falsche Doku ist fuer einen Agenten schlechter als keine — sie schickt ihn
/// mit voller Ueberzeugung an die falsche Stelle.
///
/// Die Zeilenbudgets sind der eigentliche Zweck der Aufteilung: die
/// Wurzel-`CLAUDE.md` wird in *jeder* Sitzung geladen, egal woran gearbeitet
/// wird, und ist damit die teuerste Datei im Repo. Die Teilbaum-Dateien laedt
/// Claude Code nur bei Arbeit im jeweiligen Ordner nach, die Steckbriefe nur
/// beim betroffenen Feature.
void main() {
  const maxSteckbrief = 40;
  const maxWurzel = 180;
  const maxTeilbaum = 200;
  const felder = [
    'Zweck',
    'Anforderung',
    'Einstieg',
    'Zustand',
    'Domain',
    'Backend',
    'Tests',
  ];

  final wurzelClaude = File('../CLAUDE.md');
  final featureOrdner = Directory('lib/features');

  // Ein Doku-Test, der still gruen wird, weil er das Repo nicht findet, meldet
  // Erfolg fuer eine Pruefung, die nie gelaufen ist.
  if (!wurzelClaude.existsSync() || !featureOrdner.existsSync()) {
    test('der Doku-Test findet das Repo', () {
      fail(
        'Weder ../CLAUDE.md noch lib/features gefunden. Die Architektur-Tests '
        'muessen aus dem Paket-Stammverzeichnis (Automation_App_Frontend) '
        'laufen.',
      );
    });
    return;
  }

  final features =
      featureOrdner
          .listSync()
          .whereType<Directory>()
          .map((ordner) => dateiname(ordner.path))
          .toList()
        ..sort();

  File steckbrief(String feature) => File('lib/features/$feature/FEATURE.md');

  Iterable<String> mitSteckbrief() =>
      features.where((feature) => steckbrief(feature).existsSync());

  test('jedes Feature hat einen Steckbrief', () {
    final ohne = features
        .where((feature) => !steckbrief(feature).existsSync())
        .toList();

    expect(
      ohne,
      isEmpty,
      reason:
          'Diesen Features fehlt lib/features/<feature>/FEATURE.md:\n  '
          '${ohne.join('\n  ')}\n'
          'Ohne Steckbrief muss der naechste Agent den Ordner absuchen. '
          'Den Aufbau von einem vorhandenen Steckbrief uebernehmen.',
    );
  });

  test('kein Steckbrief ist laenger als $maxSteckbrief Zeilen', () {
    final zuLang = <String>[];
    for (final feature in mitSteckbrief()) {
      final zeilen = steckbrief(feature).readAsLinesSync().length;
      if (zeilen > maxSteckbrief) zuLang.add('$feature ($zeilen Zeilen)');
    }

    expect(
      zuLang,
      isEmpty,
      reason:
          'Diese Steckbriefe sprengen ihr Budget:\n  ${zuLang.join('\n  ')}\n'
          'Ein Steckbrief ist ein Einstieg, keine Zweitfassung des Codes. Was '
          'laenger wird, gehoert in den Code oder nach docs/.',
    );
  });

  test('jeder Steckbrief traegt Ueberschrift, Felder und Fallstricke', () {
    final feldZeile = RegExp(r'^\*\*(\w+):\*\*', multiLine: true);
    final verstoesse = <String>[];

    for (final feature in mitSteckbrief()) {
      final text = steckbrief(feature).readAsStringSync();
      final zeilen = text.split('\n');

      if (zeilen.isEmpty || !zeilen.first.startsWith('# $feature ')) {
        verstoesse.add(
          '$feature: Ueberschrift beginnt nicht mit "# $feature "',
        );
      }

      final gefunden = feldZeile
          .allMatches(text)
          .map((treffer) => treffer.group(1)!)
          .toList();
      if (gefunden.join(',') != felder.join(',')) {
        verstoesse.add('$feature: Felder $gefunden statt $felder');
      }

      if (!text.contains('**Fallstricke**')) {
        verstoesse.add('$feature: Abschnitt **Fallstricke** fehlt');
      } else {
        final punkte = text
            .split('**Fallstricke**')
            .last
            .split('\n')
            .where((zeile) => zeile.trimLeft().startsWith('- '))
            .length;
        if (punkte < 2) verstoesse.add('$feature: nur $punkte Fallstrick(e)');
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Die Steckbriefe tragen absichtlich identische Feldnamen in fester '
          'Reihenfolge — nur so beantwortet ein einzelnes grep eine Frage ueber '
          'alle Features:\n  ${verstoesse.join('\n  ')}',
    );
  });

  test('die Feature-Tabelle in CLAUDE.md nennt jedes Feature', () {
    final tabelle = File('CLAUDE.md').readAsStringSync().split('### Features');
    final genannt = RegExp(
      r'^\|\s*`(\w+)`\s*\|',
      multiLine: true,
    ).allMatches(tabelle.last).map((treffer) => treffer.group(1)!).toSet();
    final vorhanden = features.toSet();

    final abweichungen = <String>[
      for (final feature in vorhanden.difference(genannt).toList()..sort())
        '$feature fehlt in der Tabelle',
      for (final feature in genannt.difference(vorhanden).toList()..sort())
        '$feature steht in der Tabelle, hat aber keinen Ordner',
    ];

    expect(
      abweichungen,
      isEmpty,
      reason:
          '${abweichungen.join('\n  ')}\n'
          'Die Feature-Tabelle in Automation_App_Frontend/CLAUDE.md ist der '
          'Einstieg in die Steckbriefe. Ein Feature, das dort fehlt, gibt es '
          'fuer einen Agenten mit frischem Kontext nicht.',
    );
  });

  test('die CLAUDE.md bleiben im Zeilenbudget', () {
    final budget = {
      '../CLAUDE.md': maxWurzel,
      'CLAUDE.md': maxTeilbaum,
      '../AutomationService/CLAUDE.md': maxTeilbaum,
    };
    final verstoesse = <String>[];

    budget.forEach((pfad, grenze) {
      final datei = File(pfad);
      if (!datei.existsSync()) {
        verstoesse.add('$pfad fehlt');
        return;
      }
      final zeilen = datei.readAsLinesSync().length;
      if (zeilen > grenze) {
        verstoesse.add('$pfad: $zeilen Zeilen (max $grenze)');
      }
    });

    expect(
      verstoesse,
      isEmpty,
      reason:
          '${verstoesse.join('\n  ')}\n'
          'Die Wurzel-CLAUDE.md wird in jeder Sitzung geladen; was nur fuer '
          'einen Teilbaum oder ein Feature gilt, gehoert in dessen CLAUDE.md '
          'bzw. FEATURE.md. Das Budget hochzusetzen macht die Aufteilung '
          'rueckgaengig.',
    );
  });

  test('kein Verweis in der Doku zeigt ins Leere', () {
    final verzeichnis = Pfadverzeichnis.ab(Directory('..'));
    final dokumente = <String>[
      '../CLAUDE.md',
      'CLAUDE.md',
      '../AutomationService/CLAUDE.md',
      for (final feature in mitSteckbrief()) 'lib/features/$feature/FEATURE.md',
      ...markdownUnter('../docs'),
      ...markdownUnter('../.claude'),
    ];
    final tot = <String>[];

    for (final pfad in dokumente) {
      final datei = File(pfad);
      if (!datei.existsSync()) continue;
      for (final token in verweiseIn(datei.readAsStringSync()).toSet()) {
        if (!verzeichnis.kennt(token)) tot.add('$pfad -> $token');
      }
    }
    tot.sort();

    expect(
      tot,
      isEmpty,
      reason:
          'Diese Dateien werden in der Doku genannt, gibt es aber nicht '
          '(mehr):\n  ${tot.join('\n  ')}\n'
          'Verweis berichtigen. Soll ein Name absichtlich ins Leere zeigen '
          '(etwa eine abgeschaffte Datei), gehoert er mit Begruendung in '
          'verweisAusnahmen in doku_verweise.dart.',
    );
  });
}
