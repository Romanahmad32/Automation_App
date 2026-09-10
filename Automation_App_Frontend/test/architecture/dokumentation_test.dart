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
/// Die Budgets sind der eigentliche Zweck der Aufteilung: die
/// Wurzel-`CLAUDE.md` wird in *jeder* Sitzung geladen, egal woran gearbeitet
/// wird, und ist damit die teuerste Datei im Repo. Die Teilbaum-Dateien laedt
/// Claude Code nur bei Arbeit im jeweiligen Ordner nach, die Steckbriefe nur
/// beim betroffenen Feature.
///
/// **Gemessen wird in Woertern, nicht in Zeilen** (seit 09.2026, Issue #131).
/// Ein Zeilenbudget misst die Umbrueche und nicht den Inhalt — und belohnt
/// damit genau das, was der 130-Zeichen-Test verbietet: Wer unter sein Budget
/// muss, zieht Absaetze zusammen, statt zu kuerzen. Beide Regeln zogen
/// gegeneinander, und die Zeilenregel gewann: Die Backend-`CLAUDE.md` hielt
/// ihre 200 Zeilen mit 55 ueberlangen Zeilen ein, alle drei `CLAUDE.md` und 7
/// von 16 Steckbriefen standen am Anschlag, und ein PR fiel wegen einer
/// einzelnen Zeile. Ein Wortbudget misst, was ein Agent tatsaechlich liest;
/// wie es umgebrochen ist, entscheidet allein die Lesbarkeit.
///
/// Die Zahlen sind die alten Zeilenbudgets, gerechnet mit den rund acht
/// Woertern, die eine umbrochene Prosazeile in diesem Repo traegt, plus dem
/// Drittel Luft aus #131: 180 → 1900, 200 → 2100, 40 → 420.
void main() {
  const maxSteckbriefWoerter = 420;
  const maxDokuZeile = 130;
  const maxWurzelWoerter = 1900;
  const maxTeilbaumWoerter = 2100;
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

  test('kein Steckbrief ist laenger als $maxSteckbriefWoerter Woerter', () {
    final zuLang = <String>[];
    for (final feature in mitSteckbrief()) {
      final anzahl = woerter(steckbrief(feature));
      if (anzahl > maxSteckbriefWoerter) {
        zuLang.add('$feature ($anzahl Woerter)');
      }
    }

    expect(
      zuLang,
      isEmpty,
      reason:
          'Diese Steckbriefe sprengen ihr Budget:\n  ${zuLang.join('\n  ')}\n'
          'Ein Steckbrief ist ein Einstieg, keine Zweitfassung des Codes. Was '
          'laenger wird, gehoert in FALLSTRICKE.md daneben (kein Budget), in '
          'den Code oder nach docs/. Gezaehlt werden Woerter: Absaetze '
          'zusammenzuziehen bringt hier nichts, nur Weglassen.',
    );
  });

  // Der Rest des Repos bricht Prosa bei rund 100 Zeichen um; 130 ist deutlich
  // darueber und trifft deshalb keinen normal gesetzten Absatz. Gegen das
  // Zusammenziehen langer Zeilen steht seit dem Wortbudget zwar kein Anreiz
  // mehr — aber der Schaden bleibt derselbe, und er ist schon einmal
  // eingetreten: ein Steckbrief mit 449 Zeichen in der laengsten Zeile, unter
  // Budget und schlechter lesbar als vorher.
  //
  // Gilt fuer die CLAUDE.md mit, nicht nur fuer die Steckbriefe: Sie werden in
  // jeder Sitzung gelesen, und die Backend-Datei hatte 55 Zeilen ueber 120
  // Zeichen, als ihr Budget noch in Zeilen gemessen wurde.
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
          'Ein Budget ist kein Grund, Absaetze zusammenzuziehen — gezaehlt '
          'werden ohnehin Woerter. Was in einen Steckbrief nicht passt, '
          'gehoert nach FALLSTRICKE.md (kein Budget); was in eine CLAUDE.md '
          'nicht passt, gehoert eine Ebene tiefer.',
    );
  });

  test('Steckbrief und FALLSTRICKE.md nennen einander', () {
    // Eine Datei, die niemand nennt, findet ein Agent mit frischem Kontext
    // nicht — und dann ist die Auslagerung ein Verlust statt einer Entlastung.
    //
    // Die Richtung "Datei da, niemand nennt sie" faengt der allgemeine
    // Verweis-Test nicht: Er laeuft ueber die Verweise, nicht ueber die
    // Dateien. Die andere Richtung deckt er inzwischen mit ab, seit ein
    // blosser Dateiname unterhalb des verweisenden Dokuments aufgeloest wird
    // (Pfadverzeichnis.kennt) — doppelt geprueft, aber mit einer Meldung, die
    // sagt, was zu tun ist.
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

      // Gefordert sind die sieben Pflichtfelder, vollstaendig und in dieser
      // Reihenfolge — mehr nicht: Ein Steckbrief darf ein achtes fettes
      // Stichwort setzen (`**Hinweis:**`, `**Ablage:**`), ohne dass diese
      // Pruefung anschlaegt. Sie hat frueher jedes zusaetzliche Feld als
      // Verstoss gemeldet und damit eine Formvorschrift erzwungen, die
      // niemand aufgeschrieben hatte. Gefiltert wird deshalb auf die
      // Pflichtfelder, bevor verglichen wird.
      final gefunden = feldZeile
          .allMatches(text)
          .map((treffer) => treffer.group(1)!)
          .where(felder.contains)
          .toList();
      if (gefunden.join(',') != felder.join(',')) {
        verstoesse.add('$feature: Pflichtfelder $gefunden statt $felder');
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
    // Bewusste Kopplung an die Ueberschrift: Nur unterhalb von "### Features"
    // steht die gesuchte Tabelle, und in der Datei stehen weitere Tabellen mit
    // Backtick-Zellen (die Regel-Tabelle am Ende). Ohne den Schnitt pruefte
    // der Test die falsche. Wird die Ueberschrift umbenannt, faellt das hier
    // auf, statt still die ganze Datei zu durchsuchen.
    const ueberschrift = '### Features';
    final wegweiser = File('CLAUDE.md').readAsStringSync();
    expect(
      wegweiser,
      contains(ueberschrift),
      reason:
          'Die Feature-Tabelle wird unter der Ueberschrift "$ueberschrift" '
          'gesucht. Wurde sie umbenannt, gehoert der Name hier nachgezogen.',
    );

    final tabelle = wegweiser.split(ueberschrift);
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

  test('die CLAUDE.md bleiben im Wortbudget', () {
    final budget = {
      '../CLAUDE.md': maxWurzelWoerter,
      'CLAUDE.md': maxTeilbaumWoerter,
      '../AutomationService/CLAUDE.md': maxTeilbaumWoerter,
    };
    final verstoesse = <String>[];

    budget.forEach((pfad, grenze) {
      final datei = File(pfad);
      if (!datei.existsSync()) {
        verstoesse.add('$pfad fehlt');
        return;
      }
      final anzahl = woerter(datei);
      if (anzahl > grenze) {
        verstoesse.add('$pfad: $anzahl Woerter (max $grenze)');
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
        if (!verzeichnis.kennt(token, genanntIn: pfad)) {
          tot.add('$pfad -> $token');
        }
      }
    }
    tot.sort();

    expect(
      tot,
      isEmpty,
      reason:
          'Diese Dateien werden in der Doku genannt, gibt es aber nicht '
          '(mehr) — oder nicht dort, wo der Verweis sie vermuten laesst:\n  '
          '${tot.join('\n  ')}\n'
          'Ein blosser Dateiname wird unterhalb des Dokuments gesucht, das ihn '
          'nennt; ist der Name im Repo eindeutig, reicht er ueberall. Sonst '
          'den Pfad dazuschreiben. Soll ein Name absichtlich ins Leere zeigen '
          '(etwa eine abgeschaffte Datei), gehoert er mit Begruendung in '
          'verweisAusnahmen in doku_verweise.dart.',
    );
  });
}
