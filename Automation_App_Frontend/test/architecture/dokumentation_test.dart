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
  const maxDokuZeile = 130;
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
  File fallstricke(String feature) =>
      File('lib/features/$feature/FALLSTRICKE.md');

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
          'laenger wird, gehoert in FALLSTRICKE.md daneben (kein Budget), in '
          'den Code oder nach docs/.',
    );
  });

  // Ohne diese Grenze begrenzt ein Zeilenbudget nur die Umbrueche, nicht die
  // Menge: Wer unter sein Budget kommen muss, zieht Zeilen zusammen. Genau das
  // war passiert — ein Steckbrief stand auf 40 Zeilen mit 449 Zeichen in der
  // laengsten davon und war schlechter lesbar als vorher. Der Rest des Repos
  // bricht Prosa bei rund 100 Zeichen um; 130 ist deutlich darueber und trifft
  // deshalb keinen normal gesetzten Absatz.
  //
  // Gilt fuer die CLAUDE.md mit, nicht nur fuer die Steckbriefe: Dort ist der
  // Druck sogar groesser, weil ihre Budgets fast ausgeschoepft sind und sie in
  // jeder Sitzung gelesen werden. Ohne die Grenze bliebe "die CLAUDE.md bleiben
  // im Zeilenbudget" gruen, waehrend die Datei unlesbarer wird — die Regel
  // wuerde dann genau den Schaden anrichten, gegen den sie geschrieben ist.
  //
  // Tabellenzeilen sind ausgenommen: Eine Tabellenzeile laesst sich nicht
  // umbrechen, ohne die Tabelle zu zerschlagen.
  test('keine Doku-Zeile ist laenger als $maxDokuZeile Zeichen', () {
    final zuBreit = <String>[];
    final dokumente = <String>[
      for (final feature in mitSteckbrief()) 'lib/features/$feature/FEATURE.md',
      '../CLAUDE.md',
      'CLAUDE.md',
      '../AutomationService/CLAUDE.md',
    ];

    for (final pfad in dokumente) {
      final datei = File(pfad);
      if (!datei.existsSync()) continue;
      for (final zeile in datei.readAsLinesSync()) {
        if (zeile.startsWith('|')) continue;
        if (zeile.length > maxDokuZeile) {
          zuBreit.add('$pfad (${zeile.length} Zeichen)');
          break;
        }
      }
    }
    zuBreit.sort();

    expect(
      zuBreit,
      isEmpty,
      reason:
          'Diese Dokumente haben ueberlange Zeilen:\n  '
          '${zuBreit.join('\n  ')}\n'
          'Ein Zeilenbudget ist kein Grund, Absaetze zusammenzuziehen. Was '
          'aus einem Steckbrief nicht in 40 umgebrochene Zeilen passt, gehoert '
          'nach FALLSTRICKE.md — die hat kein Budget; was aus einer CLAUDE.md '
          'nicht in ihre Zeilen passt, gehoert eine Ebene tiefer.',
    );
  });

  test('Steckbrief und FALLSTRICKE.md nennen einander', () {
    // Eine Datei, die niemand nennt, findet ein Agent mit frischem Kontext
    // nicht — und dann ist die Auslagerung ein Verlust statt einer Entlastung.
    //
    // Die Gegenrichtung muss hier mitgeprueft werden, weil der allgemeine
    // Verweis-Test sie nicht faengt: `FALLSTRICKE.md` traegt keinen Pfad, und
    // Pfadverzeichnis.kennt loest einen blossen Dateinamen irgendwo im Baum
    // auf. Solange *ein* Feature eine FALLSTRICKE.md hat, duerfte jeder andere
    // Steckbrief auf eine geloeschte Nachbardatei zeigen, ohne dass etwas rot
    // wird — ein toter Verweis genau der Art, gegen die es diese Tests gibt.
    final verstoesse = <String>[];
    for (final feature in features) {
      final brief = steckbrief(feature);
      final nennt =
          brief.existsSync() &&
          brief.readAsStringSync().contains('FALLSTRICKE.md');
      final liegtDaneben = fallstricke(feature).existsSync();

      if (liegtDaneben && !nennt) {
        verstoesse.add(
          '$feature: FALLSTRICKE.md liegt da, FEATURE.md nennt sie nicht',
        );
      } else if (nennt && !liegtDaneben) {
        verstoesse.add(
          '$feature: FEATURE.md nennt FALLSTRICKE.md, daneben liegt keine',
        );
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Steckbrief und FALLSTRICKE.md sind auseinandergelaufen:\n  '
          '${verstoesse.join('\n  ')}\n'
          'Im Abschnitt **Fallstricke** darauf verweisen — oder den Verweis '
          'streichen, wenn die Datei weg ist.',
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

  // Features, deren Steckbrief keinen Test nennen kann, weil es keinen gibt.
  // Namentlich, damit die Luecke sichtbar bleibt, statt sich hinter einem
  // Gedankenstrich zu verstecken — diese Liste soll leer werden.
  const ohneTests = {
    'dev_simulation': 'nur in kDebugMode sichtbar, nicht im Auslieferstand',
  };

  test('das Feld Tests nennt einen Testpfad statt eines Gedankenstrichs', () {
    // Der allgemeine Verweis-Test faengt das nicht: Ein Gedankenstrich ist
    // kein Verweis und faellt deshalb durch jede Pruefung auf tote Pfade. Er
    // verfaellt zudem still — geprueft an zwei Steckbriefen, die noch "—"
    // trugen, als ihre Tests laengst dalagen.
    final verstoesse = <String>[];

    for (final feature in mitSteckbrief()) {
      final text = steckbrief(feature).readAsStringSync();
      // Das Feld reicht bis zum naechsten fett gesetzten Feldnamen.
      final feld = text
          .split('**Tests:**')
          .last
          .split(RegExp(r'^\*\*', multiLine: true))
          .first;
      final nenntPfad = feld.contains(RegExp('`test/'));

      if (!nenntPfad && !ohneTests.containsKey(feature)) {
        verstoesse.add('$feature: nennt keinen Pfad unter test/');
      } else if (nenntPfad && ohneTests.containsKey(feature)) {
        verstoesse.add(
          '$feature: nennt jetzt Tests — Eintrag aus ohneTests streichen',
        );
      }

      // Der eigene Testordner muss im Feld vorkommen. Ohne das bleibt ein
      // Steckbrief gruen, der auf Nachbartests verweist, waehrend daneben
      // laengst ein eigener Ordner liegt — die Aussage stimmt dann nicht mehr,
      // und genau so verfaellt das Feld unbemerkt.
      if (Directory('test/features/$feature').existsSync() &&
          !feld.contains('`test/features/$feature/')) {
        verstoesse.add(
          '$feature: test/features/$feature/ liegt da, das Feld nennt ihn nicht',
        );
      }
    }
    verstoesse.sort();

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Das Feld **Tests:** im Steckbrief:\n  ${verstoesse.join('\n  ')}\n'
          'Es nennt den Einstieg in die Absicherung eines Features. Steht dort '
          'ein blosser Gedankenstrich, kostet die Frage "ist das getestet?" '
          'jedes Mal eine Suche — und die Antwort ist oft ja, nur an einer '
          'Stelle, die niemand vermutet. Den Pfad eintragen (auch einen in '
          'einem fremden Feature-Ordner, wenn die Tests dort liegen). Gibt es '
          'wirklich keinen, gehoert das Feature mit Grund in ohneTests.',
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
      // Alle Feature-Dokumente, also FEATURE.md samt der FALLSTRICKE.md daneben.
      ...markdownUnter('lib/features'),
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
