import 'package:flutter_test/flutter_test.dart';

import 'dart_source_files.dart';

/// Jede `Scrollbar(`/`RawScrollbar(` in `lib/` trägt einen eigenen
/// `controller:`.
///
/// Hintergrund: Ohne `controller` greift die Scrollbar auf den
/// `PrimaryScrollController` zurück. Auf dem Desktop (Windows, die einzige
/// Zielplattform) hängt der aber nicht an einer `SingleChildScrollView` —
/// die ist dort nicht `primary`. Die Scrollbar findet dann keine
/// `ScrollPosition`, und jedes Scrollen wirft im Debug-Build eine Assertion
/// („The Scrollbar's ScrollController has no ScrollPosition attached"). Im
/// Release-Build bleibt sie stumm, deshalb fiel es nur auf, wenn jemand die
/// Seite im Debug-Build bedient (so geschehen bei „Neuer Mandant"). Das Muster:
/// Controller im State anlegen, in `dispose` freigeben, an Scrollbar **und**
/// ScrollView geben.
void main() {
  test('jede Scrollbar in lib/ hat einen controller', () {
    final verstoesse = <String>[];

    for (final datei in dartQuelldateien('lib')) {
      final pfad = relPfad(datei);
      for (final stelle in scrollbarsOhneController(datei.readAsStringSync())) {
        verstoesse.add('$pfad: $stelle');
      }
    }

    expect(
      verstoesse,
      isEmpty,
      reason:
          'Scrollbar ohne controller: auf dem Desktop wirft sie beim Scrollen '
          'eine Assertion (kein PrimaryScrollController an der ScrollView). '
          'Eigenen ScrollController anlegen und an Scrollbar und ScrollView '
          'geben:\n  ${verstoesse.join('\n  ')}',
    );
  });

  test('erkennt eine Scrollbar ohne controller', () {
    const quelle = '''
Widget build(BuildContext context) {
  return Scrollbar(
    child: SingleChildScrollView(controller: c, child: Text('x')),
  );
}
''';
    expect(scrollbarsOhneController(quelle), hasLength(1));
    expect(
      scrollbarsOhneController('RawScrollbar(child: ListView())'),
      hasLength(1),
    );
  });

  test('lässt eine Scrollbar mit controller durch', () {
    const quelle = '''
Scrollbar(
  controller: _controller,
  child: SingleChildScrollView(controller: _controller, child: Text('x')),
)
''';
    expect(scrollbarsOhneController(quelle), isEmpty);
  });

  test('zählt einen controller in der Kind-Struktur nicht mit', () {
    const quelle =
        "Scrollbar(child: SingleChildScrollView(controller: c, child: Text('x')))";
    expect(scrollbarsOhneController(quelle), hasLength(1));
  });
}

/// Fundstellen (Zeile) aller `Scrollbar(`/`RawScrollbar(`-Aufrufe in [quelle],
/// deren Argumentliste **auf oberster Ebene** kein `controller:` enthält.
///
/// Geklammert wird bis zur schließenden Klammer; Argumente verschachtelter
/// Aufrufe (etwa der `controller:` der ScrollView im `child:`) zählen nicht.
List<String> scrollbarsOhneController(String quelle) {
  final treffer = RegExp(r'(?<![A-Za-z0-9_])(Raw)?Scrollbar\(');
  final fundstellen = <String>[];

  for (final m in treffer.allMatches(quelle)) {
    final zeile = '\n'.allMatches(quelle.substring(0, m.start)).length + 1;
    var tiefe = 1;
    var hatController = false;
    for (var i = m.end; i < quelle.length && tiefe > 0; i++) {
      final z = quelle[i];
      if (z == '(' || z == '[' || z == '{') {
        tiefe++;
      } else if (z == ')' || z == ']' || z == '}') {
        tiefe--;
      } else if (tiefe == 1 && quelle.startsWith('controller:', i)) {
        final davor = i == 0 ? ' ' : quelle[i - 1];
        if (!RegExp(r'[A-Za-z0-9_]').hasMatch(davor)) hatController = true;
      }
    }
    if (!hatController) fundstellen.add('Zeile $zeile: ${m.group(0)}');
  }
  return fundstellen;
}
