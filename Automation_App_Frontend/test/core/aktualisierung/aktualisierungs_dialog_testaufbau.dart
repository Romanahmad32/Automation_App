import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'aktualisierung_doubles.dart';

/// Das App-Theme in der Schriftstufe [stufe] — die Vorgabe der App ist
/// „Größer“, der härteste Fall für Überläufe „Am größten“.
ThemeData appTheme([Schriftstufe stufe = Schriftstufe.groesser]) =>
    MaterialTheme(ThemeData.light().textTheme, schriftstufe: stufe).light();

/// Öffnet den Dialog „App aktualisieren“ über [AktualisierungsDialog.zeigen]
/// — wie die App, mit echter Dialogroute — auf einem Cubit, dessen Dienst
/// mit [stand] antwortet.
Future<CubitAufbau> oeffneDialog(
  WidgetTester tester,
  AktualisierungsStand stand, {
  bool testmodus = false,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final aufbau = CubitAufbau(
    repository: AktualisierungRepositoryDouble(anfang: stand),
    testmodus: testmodus,
  );
  addTearDown(aufbau.cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? appTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                AktualisierungsDialog.zeigen(context, cubit: aufbau.cubit),
            child: const Text('öffnen'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('öffnen'));
  await zeigeBild(tester);
  return aufbau;
}

/// Ein paar Bilder weiter — ohne `pumpAndSettle`: Im Zustand 2e läuft ein
/// unbestimmter Balken, „bis nichts mehr animiert“ käme nie.
Future<void> zeigeBild(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Die Knöpfe im Aktionsbereich des Dialogs.
Finder dialogKnoepfe() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);
