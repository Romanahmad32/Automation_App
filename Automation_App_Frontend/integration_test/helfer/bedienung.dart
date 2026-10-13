import 'package:automation_app/core/general_widgets/drawer/side_bar_item.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_art.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_karte.dart';
import 'package:automation_app/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';

import 'e2e_umgebung.dart';

import 'package:material_ui/material_ui.dart';

/// Bedienung der laufenden App für die E2E-Suite (#184) — nur über Keys und
/// eindeutige Texte, nie über Koordinaten.
///
/// **Kein `pumpAndSettle`.** Die App zeigt beim Laden Ringe, die sich drehen,
/// solange ein Aufruf läuft; „bis nichts mehr animiert" träte dann erst nach
/// dem Timeout ein (dieselbe Falle wie in `vorgang_starten/FALLSTRICKE.md`).
/// Stattdessen wartet [warteAuf] in kurzen Takten auf das, was als Nächstes
/// erscheinen soll — in Echtzeit, denn die Suite spricht mit einem echten
/// Dienst.
///
/// **Eine Fehler-Rückmeldung bricht ab.** Sie bleibt stehen, bis jemand sie
/// schließt (`RueckmeldungsArt.fehler`); ein Durchlauf, der daneben weiter auf
/// sein Ziel wartet, liefe nur in den Timeout und verlöre die Ursache.
class Bedienung {
  final WidgetTester tester;

  Bedienung(this.tester);

  static const Duration takt = Duration(milliseconds: 100);
  static const Duration standardFrist = Duration(seconds: 30);

  /// Erster Start eines Worktrees: Dienst übernehmen, DI, erste Seite.
  static const Duration startFrist = Duration(seconds: 120);

  /// Die logische Fläche, auf der die App im Test ausgelegt wird — unabhängig
  /// von Fenstergröße und Skalierung des Rechners, auf dem die Suite läuft
  /// (das Fenster des Debug-Builds hat bei 250 % nur rund 1270 × 690). Das
  /// Bild wird in das Fenster eingepasst; getippt wird in dieser Fläche.
  ///
  /// So hoch, dass „Neuer Mandant“ ohne Scrollen ganz draufpasst (gemessen
  /// 13.10.2026: 1076 px Inhalt) — der Durchlauf hängt so nicht an der
  /// Fenstergröße des Rechners.
  static const Size flaeche = Size(1600, 1200);

  /// Startet die App über `lib/main.dart` — unverändert, ohne eigenes
  /// Binding dort — und wartet, bis die Seitenleiste steht.
  ///
  /// **Schranke:** ohne bestandene [E2eUmgebung.stelleTestmodusSicher]
  /// verweigert schon der Start. Sonst übernähme der BackendLauncher ohne
  /// Defines den echten Dienst auf Port 5143, und „Senden“ ginge echt raus.
  /// [tippe] und [gebeEin] prüfen dasselbe noch einmal, falls ein Durchlauf
  /// die App auf anderem Weg bekommt — die Prüfung kostet nichts.
  Future<void> starteApp() async {
    _verlangeSchranke('die App zu starten');
    await tester.binding.setSurfaceSize(flaeche);
    app.main();
    await warteAuf(
      find.byType(SidebarItem),
      frist: startFrist,
      was: 'die Seitenleiste der App',
    );
  }

  /// Wartet, bis [finder] etwas findet, und gibt ihn zurück.
  Future<Finder> warteAuf(
    Finder finder, {
    Duration frist = standardFrist,
    String? was,
  }) async {
    final ende = DateTime.now().add(frist);
    while (DateTime.now().isBefore(ende)) {
      await tester.pump(takt);
      _brichAbBeiFehlermeldung();
      if (finder.evaluate().isNotEmpty) return finder;
    }
    fail('Nach ${frist.inSeconds} s nicht erschienen: ${was ?? finder}');
  }

  /// Wartet, bis [finder] nichts mehr findet (ein Dialog ist zu, ein Ring weg).
  Future<void> warteBisWeg(
    Finder finder, {
    Duration frist = standardFrist,
    String? was,
  }) async {
    final ende = DateTime.now().add(frist);
    while (DateTime.now().isBefore(ende)) {
      await tester.pump(takt);
      _brichAbBeiFehlermeldung();
      if (finder.evaluate().isEmpty) return;
    }
    fail('Nach ${frist.inSeconds} s immer noch da: ${was ?? finder}');
  }

  /// Wartet, bis der Knopf in oder über [finder] bedienbar ist.
  Future<void> warteAufAktiv(
    Finder finder, {
    Duration frist = standardFrist,
    String? was,
  }) async {
    final ende = DateTime.now().add(frist);
    while (DateTime.now().isBefore(ende)) {
      await tester.pump(takt);
      _brichAbBeiFehlermeldung();
      if (finder.evaluate().isNotEmpty && _istAktiv(finder.first)) return;
    }
    fail('Nach ${frist.inSeconds} s nicht bedienbar: ${was ?? finder}');
  }

  /// Ins Bild holen und antippen.
  Future<void> tippe(Finder finder, {String? was}) async {
    _verlangeSchranke('etwas anzutippen');
    await warteAuf(finder, was: was);
    await _insBild(finder);
    await tester.tap(finder.first);
    await tester.pump(takt);
  }

  /// Scrollt nur, wenn [finder] nicht schon antippbar ist: Jeder Scroll ist
  /// ein Ereignis mehr, das die Seite verarbeiten muss — und ein überflüssiger
  /// verschiebt die Ansicht, die der nächste Schritt erwartet.
  Future<void> _insBild(Finder finder) async {
    if (finder.first.hitTestable().evaluate().isNotEmpty) return;
    await tester.ensureVisible(finder.first);
    await tester.pump(takt);
  }

  /// Wartet, bis der Knopf bedienbar ist, und tippt ihn an.
  Future<void> tippeAktiv(
    Finder finder, {
    Duration frist = standardFrist,
    String? was,
  }) async {
    await warteAufAktiv(finder, frist: frist, was: was);
    await tippe(finder, was: was);
  }

  /// Text in das Feld [feld] schreiben (ersetzt den bisherigen Inhalt).
  Future<void> gebeEin(Finder feld, String text, {String? was}) async {
    _verlangeSchranke('etwas einzugeben');
    await warteAuf(feld, was: was);
    await _insBild(feld);
    await tester.enterText(feld.first, text);
    await tester.pump(takt);
  }

  /// Wechselt über die Seitenleiste in den Reiter [beschriftung]. Die
  /// Beschriftung steht auch eingeklappt im Baum (`SidebarItem`).
  Future<void> waehleReiter(String beschriftung) => tippe(
    find.widgetWithText(SidebarItem, beschriftung),
    was: 'Reiter „$beschriftung"',
  );

  /// Öffnet das Auswahlfeld [feld], filtert bei Bedarf mit [filter] und wählt
  /// den Eintrag [eintrag] (meist dessen Key).
  ///
  /// Das Menü schließt sich, sobald die Seite darunter scrollt — deshalb holt
  /// [tippe] nur ins Bild, was nicht schon antippbar ist.
  Future<void> waehleAus(Finder feld, Finder eintrag, {String? filter}) async {
    await tippe(feld);
    if (filter != null) await gebeEin(feld, filter);
    await tippe(eintrag, was: 'den Eintrag im geöffneten Menü');
  }

  /// Der Knopf mit der Beschriftung [text] — nicht eine gleichlautende
  /// Überschrift daneben (etwa „In Akte ablegen" über dem Knopf).
  static Finder knopf(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );

  /// Der Text im Eingabefeld [feld] (ein `TextField` oder darüber).
  String textIn(Finder feld) {
    final editierbar = find.descendant(
      of: feld,
      matching: find.byType(EditableText),
      matchRoot: true,
    );
    return tester.widget<EditableText>(editierbar.first).controller.text;
  }

  void _verlangeSchranke(String vorhaben) {
    if (E2eUmgebung.geprueft) return;
    throw StateError(
      'Die Bedienung weigert sich, $vorhaben, bevor '
      'E2eUmgebung.stelleTestmodusSicher() bestanden hat — sonst träfe die '
      'Suite womöglich den echten Dienst. Abgebrochen.',
    );
  }

  bool _istAktiv(Finder finder) {
    final knopf = find.ancestor(
      of: finder,
      matching: find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton || widget is IconButton,
      ),
      matchRoot: true,
    );
    if (knopf.evaluate().isEmpty) return true;
    final widget = tester.widget(knopf.first);
    return switch (widget) {
      ButtonStyleButton(:final enabled) => enabled,
      IconButton(:final onPressed) => onPressed != null,
      _ => true,
    };
  }

  void _brichAbBeiFehlermeldung() {
    final fehler = find.byWidgetPredicate(
      (widget) =>
          widget is RueckmeldungsKarte &&
          widget.inhalt.art == RueckmeldungsArt.fehler,
    );
    if (fehler.evaluate().isEmpty) return;
    final karte = tester.widget<RueckmeldungsKarte>(fehler.first);
    fail('Die App meldet einen Fehler: ${karte.inhalt.text}');
  }
}
