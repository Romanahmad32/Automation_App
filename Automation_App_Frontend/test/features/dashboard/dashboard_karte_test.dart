import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_karte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Absprung („Alle Vorgänge", „Zum Postfach", …) gehört an die rechte
/// Kartenkante und muss beim Verbreitern/Verschmälern der Karte mitwandern —
/// vorher stand er wegen zweier flexibler Zeilenkinder in der Kartenmitte.
void main() {
  Future<void> pumpe(WidgetTester tester, double breite) async {
    tester.view.physicalSize = const Size(2000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: breite,
            child: const DashboardKarte(
              titel: 'Offene Vorgänge',
              icon: Icons.folder_open_outlined,
              umfang: '3 von 12',
              aktionLabel: 'Alle Vorgänge',
              zielTab: 7,
              child: SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );
  }

  double abstandRechts(WidgetTester tester) {
    final karte = tester.getRect(find.byType(Card));
    final knopf = tester.getRect(find.text('Alle Vorgänge'));
    return karte.right - knopf.right;
  }

  testWidgets('sitzt rechts im Kartenkopf', (tester) async {
    await pumpe(tester, 1200);

    final knopf = tester.getRect(find.byType(FilledButton));
    final karte = tester.getRect(find.byType(Card));
    // Nur die Kopfzeilen-Polsterung trennt Knopf und Kartenkante.
    expect(karte.right - knopf.right, lessThan(24));
  });

  testWidgets('wandert mit der Kartenbreite mit', (tester) async {
    await pumpe(tester, 600);
    final schmal = abstandRechts(tester);

    await pumpe(tester, 1200);
    final breit = abstandRechts(tester);

    // Gleicher Abstand zur rechten Kante — der Knopf klebt an der Karte,
    // nicht an einer festen Position.
    expect(breit, closeTo(schmal, 1));
  });

  testWidgets('ist bequem zu treffen', (tester) async {
    await pumpe(tester, 1200);

    expect(tester.getSize(find.byType(FilledButton)).height, greaterThan(40));
  });
}
