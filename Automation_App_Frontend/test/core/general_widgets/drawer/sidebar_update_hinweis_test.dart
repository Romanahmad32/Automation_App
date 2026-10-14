import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/general_widgets/drawer/sidebar_update_hinweis.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../aktualisierung/aktualisierung_doubles.dart';
import '../../aktualisierung/aktualisierungs_dialog_testaufbau.dart';

/// Der Hinweis im Fuß der Seitenleiste in seinen drei Zuständen (#196):
/// 1a verfügbar, 1b lädt (Ring + Prozent), 1c bereit (getönte Kachel) — ein-
/// und ausgeklappt, mit dem ganzen Satz im Tooltip.
void main() {
  const mib = 1024 * 1024;

  /// Die Leiste ist 72 bzw. 236 px breit, mit 1 px Rand rechts — wie in
  /// `AppSidebar`. Die Breite läuft beim Umschalten mit, wie dort.
  Widget leiste(
    AktualisierungsStand? stand, {
    required bool ausgeklappt,
    Duration dauer = Duration.zero,
    VoidCallback? beiDruck,
  }) => Align(
    alignment: Alignment.topLeft,
    child: AnimatedContainer(
      duration: dauer,
      width: ausgeklappt ? 236 : 72,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey)),
      ),
      child: SidebarUpdateHinweis(
        ansicht: stand == null ? null : AktualisierungsAnsicht(stand: stand),
        isExtended: ausgeklappt,
        collapsedWidth: 72,
        animationDuration: dauer,
        beiDruck: beiDruck ?? () {},
      ),
    ),
  );

  Future<void> zeige(
    WidgetTester tester,
    AktualisierungsStand? stand, {
    required bool ausgeklappt,
    Schriftstufe stufe = Schriftstufe.groesser,
    VoidCallback? beiDruck,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(stufe),
        home: Scaffold(
          body: leiste(stand, ausgeklappt: ausgeklappt, beiDruck: beiDruck),
        ),
      ),
    );
    await tester.pump();
  }

  final verfuegbar = standMit(AktualisierungsZustand.verfuegbar);
  final laedt = standMit(AktualisierungsZustand.laedt, geladen: 54 * mib);
  final bereit = standMit(AktualisierungsZustand.bereit);

  testWidgets('ohne Update in Sicht steht nichts da', (tester) async {
    for (final stand in [
      null,
      standMit(AktualisierungsZustand.unbekannt),
      standMit(AktualisierungsZustand.aktuell, neueVersion: null),
    ]) {
      await zeige(tester, stand, ausgeklappt: true);
      expect(find.byKey(SidebarUpdateHinweis.schluessel), findsNothing);
    }
  });

  testWidgets('1a verfügbar: Beschriftung, Tooltip, Klick', (tester) async {
    var gedrueckt = 0;
    await zeige(
      tester,
      verfuegbar,
      ausgeklappt: true,
      beiDruck: () => gedrueckt++,
    );

    expect(find.text('Update verfügbar'), findsOneWidget);
    expect(find.byTooltip('Version 1.4.0 ist verfügbar'), findsOneWidget);
    await tester.tap(find.byKey(SidebarUpdateHinweis.schluessel));
    expect(gedrueckt, 1);
  });

  testWidgets('1a gilt auch nach einem Fehler', (tester) async {
    await zeige(
      tester,
      standMit(AktualisierungsZustand.fehler, meldung: 'unterbrochen'),
      ausgeklappt: true,
    );

    expect(find.text('Update verfügbar'), findsOneWidget);
  });

  testWidgets('1b lädt: Ring, Balken und abgerundete Prozent', (tester) async {
    await zeige(tester, laedt, ausgeklappt: true);

    expect(find.text('Update wird geladen'), findsOneWidget);
    expect(find.text('58 %'), findsOneWidget);
    expect(find.byTooltip('Update wird geladen · 58 %'), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, closeTo(54 / 92, 0.001));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('1c bereit: Kachel in der Tertiärfarbe', (tester) async {
    await zeige(tester, bereit, ausgeklappt: true);

    expect(find.text('Update bereit'), findsOneWidget);
    expect(find.text('Neu starten'), findsOneWidget);
    expect(find.byTooltip('Update bereit – neu starten'), findsOneWidget);
    final symbol = tester.widget<Icon>(find.byIcon(Icons.restart_alt));
    final schema = Theme.of(tester.element(find.byIcon(Icons.restart_alt)))
        .colorScheme;
    expect(symbol.color, schema.tertiary);
  });

  testWidgets(
    'eingeklappt bleibt jeder Zustand sichtbar und läuft nicht über',
    (tester) async {
      for (final stand in [verfuegbar, laedt, bereit]) {
        await zeige(tester, stand, ausgeklappt: false);
        expect(find.byKey(SidebarUpdateHinweis.schluessel), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '${stand.zustand}');
      }
      // Der Ring zeigt den Stand auch eingeklappt.
      await zeige(tester, laedt, ausgeklappt: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('bei „Am größten“ läuft ausgeklappt nichts über', (tester) async {
    for (final stand in [verfuegbar, laedt, bereit]) {
      await zeige(
        tester,
        stand,
        ausgeklappt: true,
        stufe: Schriftstufe.amGroessten,
      );
      expect(tester.takeException(), isNull, reason: '${stand.zustand}');
    }
  });

  testWidgets('beim Aufklappen läuft 1b in keinem Bild über', (tester) async {
    const dauer = Duration(milliseconds: 200);
    Widget app(bool ausgeklappt) => MaterialApp(
      theme: appTheme(),
      home: Scaffold(
        body: leiste(laedt, ausgeklappt: ausgeklappt, dauer: dauer),
      ),
    );

    await tester.pumpWidget(app(false));
    await tester.pumpWidget(app(true));
    for (var bild = 0; bild < 8; bild++) {
      await tester.pump(const Duration(milliseconds: 25));
      expect(tester.takeException(), isNull, reason: 'Bild $bild');
    }
  });
}
