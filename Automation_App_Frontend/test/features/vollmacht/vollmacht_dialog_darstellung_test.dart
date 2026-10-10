import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_dialog.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_drucker_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'vollmacht_doubles.dart';

/// Was der Anwalt im Vollmacht-Dialog sieht (§4.11, #164): Vorschau neben
/// oder unter den Feldern, die Druckerzeile und das Ergebnis nach dem Druck —
/// auch bei „Am größten" ohne Überlauf.
void main() {
  const referenz = '12/26 C05_GG-XY 1';
  final vorgang = Vorgang(
    referenz: referenz,
    angefragtAm: DateTime(2026, 9, 1),
    rechtsgebiet: 'Strafrecht',
    abteilung: 'C05',
  );

  /// Aufbau im testWidgets, nie in setUp: Sonst läuft der Cubit außerhalb
  /// der Fake-Zone, und der Test wartet ewig.
  Future<({VollmachtCubit cubit, VollmachtRepositoryDouble dienst})> baue(
    WidgetTester tester, {
    VollmachtDrucker? drucker,
    bool drucken = false,
  }) async {
    late VollmachtCubit cubit;
    final dienst = VollmachtRepositoryDouble();
    await tester.runAsync(() async {
      if (drucker != null) dienst.drucker = drucker;
      final vorgaenge = VollmachtVorgaengeDouble()..bestand[referenz] = vorgang;
      cubit = (await baueVollmachtCubit(dienst, vorgaenge)).cubit;
      await cubit.starte(vorgang, const []);
      if (drucken) {
        // Gedruckt wird hier vor dem Dialog — den Drucker hätte er vorher
        // abgefragt.
        await cubit.ladeDrucker();
        await cubit.drucke();
      }
    });
    addTearDown(cubit.close);
    return (cubit: cubit, dienst: dienst);
  }

  Future<void> zeigeDialog(
    WidgetTester tester,
    VollmachtCubit cubit, {
    required Size fenster,
  }) async {
    tester.view.physicalSize = fenster;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        // Das echte, auf „Am größten" angehobene Theme (Issue #57).
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: Schriftstufe.amGroessten,
        ).light(),
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const VollmachtDialog(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'breites Fenster: Vorschau neben den Feldern, nichts läuft über',
    (tester) async {
      final (:cubit, :dienst) = await baue(tester);

      await zeigeDialog(tester, cubit, fenster: const Size(1400, 1000));

      expect(tester.takeException(), isNull);
      expect(
        dienst.vorschauAuftraege,
        hasLength(1),
        reason:
            'Der Dialog bestellt die erste Vorschau beim Öffnen, genau einmal.',
      );
      expect(find.text('Aktualisieren'), findsOneWidget);
      expect(
        find.text('Drucker: Kanzleidrucker (Windows-Standard)'),
        findsOneWidget,
      );
      final felder = tester.getTopLeft(find.text('Straße und Hausnummer'));
      final vorschau = tester.getTopLeft(find.text('Vorschau'));
      expect(
        vorschau.dx,
        greaterThan(felder.dx),
        reason: 'Vorschau steht rechts',
      );
    },
  );

  testWidgets('schmales Fenster bei „Am größten": Vorschau unter den Feldern', (
    tester,
  ) async {
    final (:cubit, :dienst) = await baue(tester);

    await zeigeDialog(tester, cubit, fenster: const Size(800, 900));

    expect(tester.takeException(), isNull);
    expect(dienst.vorschauAuftraege, hasLength(1));
    expect(find.text('Aktualisieren', skipOffstage: false), findsOneWidget);
  });

  testWidgets('ohne Drucker ist „Drucken" gesperrt und die Zeile sagt warum', (
    tester,
  ) async {
    final (:cubit, :dienst) = await baue(
      tester,
      drucker: const VollmachtDrucker(
        zustand: VollmachtDruckerZustand.keinDrucker,
        hinweis: 'In Windows ist kein Standarddrucker eingerichtet.',
      ),
    );

    await zeigeDialog(tester, cubit, fenster: const Size(1400, 1000));

    // Den Drucker fragt der Dialog selbst ab, nachdem er aufgegangen ist.
    expect(dienst.druckerAbfragen, 1);
    final drucken = find.widgetWithText(FilledButton, 'Drucken');
    expect(tester.widget<FilledButton>(drucken).onPressed, isNull);
    expect(find.textContaining('kein Standarddrucker'), findsOneWidget);
    final word = find.widgetWithText(OutlinedButton, 'In Word öffnen');
    expect(tester.widget<OutlinedButton>(word).onPressed, isNotNull);
  });

  testWidgets('ein offline gemeldeter Drucker nennt den Ausweg', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VollmachtDruckerZeile(
            drucker: VollmachtDrucker(
              name: 'Kanzleidrucker',
              zustand: VollmachtDruckerZustand.offline,
              hinweis: 'Windows meldet den Drucker als offline.',
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('als offline'), findsOneWidget);
    expect(find.textContaining('„In Word öffnen"'), findsOneWidget);
  });

  testWidgets('nach dem Druck bleibt das Ergebnis stehen, bis „Fertig"', (
    tester,
  ) async {
    final (:cubit, dienst: _) = await baue(tester, drucken: true);

    await zeigeDialog(tester, cubit, fenster: const Size(1400, 1000));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('an Kanzleidrucker übergeben'), findsOneWidget);
    expect(find.text('Am Vorgang als gedruckt vermerkt'), findsOneWidget);
    expect(find.text('Kein Blatt gekommen?'), findsOneWidget);
    expect(find.text('Erneut drucken'), findsOneWidget);
    expect(find.text('Vermerk zurücknehmen'), findsOneWidget);
    expect(find.text('Fertig'), findsOneWidget);
  });
}
