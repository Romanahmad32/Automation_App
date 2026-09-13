import 'package:automation_app/features/dashboard/domain/services/dashboard_uebersicht.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_offene_vorgaenge_karte.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_vollmacht_hinweis.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reine Anzeigeprüfung — ohne Tipp: [DashboardVollmachtHinweis] springt über
/// `AutoTabsRouter.of(context)`, das außerhalb der Tab-Navigation der
/// eingebetteten App wirft (siehe `FEATURE.md` von `dashboard`). Das Bauen
/// selbst löst den Sprung nicht aus, deshalb darf hier ohne `AutoTabsRouter`
/// gepumpt werden.
void main() {
  Future<void> pumpe(WidgetTester tester, int anzahl) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DashboardVollmachtHinweis(anzahl: anzahl)),
      ),
    );
  }

  testWidgets('zeigt die Einzahl bei genau einem Vorgang', (tester) async {
    await pumpe(tester, 1);

    expect(
      find.text('1 offener Vorgang ohne gedruckte Vollmacht'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.draw_outlined), findsOneWidget);
  });

  testWidgets('zeigt die Mehrzahl bei mehreren Vorgängen', (tester) async {
    await pumpe(tester, 3);

    expect(
      find.text('3 offene Vorgänge ohne gedruckte Vollmacht'),
      findsOneWidget,
    );
  });

  testWidgets('die Karte "Offene Vorgänge" zeigt den Hinweis nicht, wenn alle '
      'offenen Vorgänge vermerkt sind', (tester) async {
    final vorgang = Vorgang(
      referenz: '1/26 C03_HG-E 1',
      angefragtAm: DateTime(2026, 6, 1),
      status: VorgangStatus.angefragt,
      vollmachtGedrucktAm: DateTime(2026, 6, 2),
    );
    final uebersicht = DashboardUebersicht.aus([vorgang]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardOffeneVorgaengeKarte(uebersicht: uebersicht),
        ),
      ),
    );

    expect(find.byType(DashboardVollmachtHinweis), findsNothing);
  });
}
