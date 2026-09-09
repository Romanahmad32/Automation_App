import 'package:automation_app/features/backup/presentation/widgets/synchronisations_bereich.dart';
import 'package:automation_app/features/backup/domain/entities/letzte_sicherung.dart';
import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_angebot.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/widgets/synchronisations_leiste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_doubles.dart';

class SynchronisationsDouble extends BackupDouble {
  SynchronisationsDouble() : super(const UebergabeStand());
  UebergabeStand stand = const UebergabeStand(
    ablageOrdner: 'OneDrive/Sicherungen',
    zustand: 'warten',
  );
  int abfragen = 0;
  int bereitstellungen = 0;
  Completer<void>? lauf;
  bool fehler = false;

  @override
  Future<UebergabeStand> uebergabeStand() async {
    abfragen++;
    if (fehler) throw StateError('offline');
    return stand;
  }

  @override
  Future<void> jetztBereitstellen() async {
    bereitstellungen++;
    await lauf?.future;
  }
}

void main() {
  late SynchronisationsDouble backup;
  setUp(() {
    backup = SynchronisationsDouble();
    getIt.registerSingleton<BackupRepository>(backup);
  });
  tearDown(getIt.reset);

  Future<void> zeigen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SynchronisationsLeiste())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'prüft ohne Appbar-Leiste weiter und zeigt den Stand in Einstellungen',
    (tester) async {
      final sichtbar = ValueNotifier(false);
      addTearDown(sichtbar.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SynchronisationsLeiste(
              child: ValueListenableBuilder<bool>(
                valueListenable: sichtbar,
                builder: (context, wert, child) => wert
                    ? const SingleChildScrollView(
                        child: SynchronisationsAnsicht(),
                      )
                    : const Text('Andere App-Seite'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Jetzt bereitstellen'), findsNothing);
      backup.stand = UebergabeStand(
        ablageOrdner: 'OneDrive',
        eigenerStandGesichertAm: DateTime(2026, 9, 7, 10, 15),
        letzteSicherung: LetzteSicherung(
          zeitpunkt: DateTime(2026, 9, 7, 10, 15),
          gelungen: true,
          datei: 'buero-stand.zip',
        ),
      );
      await tester.pump(const Duration(seconds: 15));
      expect(backup.abfragen, 2);
      sichtbar.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Jetzt bereitstellen'), findsOneWidget);
      expect(find.textContaining('alle 30 Minuten'), findsOneWidget);
      expect(find.textContaining('10:15'), findsNWidgets(2));
      expect(
        find.text('Bereitgestellte Datei: buero-stand.zip'),
        findsOneWidget,
      );
      expect(backup.abfragen, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('zeigt ohne Ablageordner keine aktive Automatik an', (
    tester,
  ) async {
    backup.stand = const UebergabeStand(zustand: 'nichtEingerichtet');
    await zeigen(tester);
    expect(
      find.textContaining('Automatische Bereitstellung ist aus'),
      findsOneWidget,
    );
    expect(find.textContaining('alle 30 Minuten'), findsNothing);
    final knopf = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Jetzt bereitstellen'),
    );
    expect(knopf.onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'erkennt einen verspäteten Download ohne Neustart und ohne automatische Übernahme',
    (tester) async {
      await zeigen(tester);
      expect(find.textContaining('Warte auf die Übertragung'), findsOneWidget);
      backup.stand = UebergabeStand(
        ablageOrdner: 'OneDrive',
        zustand: 'angebot',
        angebot: UebergabeAngebot(
          rechnername: 'BUERO',
          zuletztGearbeitet: DateTime(2026, 9, 7),
          gesichertAm: DateTime(2026, 9, 7),
          sicherung: 'stand.zip',
          programmfassung: '1.0',
        ),
      );
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.textContaining('Stand von BUERO verfügbar'), findsOneWidget);
      expect(backup.abfragen, 2);
      expect(backup.uebernahmen, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('zeigt Bereitstellung und lässt keine doppelten Aufträge zu', (
    tester,
  ) async {
    backup.lauf = Completer<void>();
    await zeigen(tester);
    await tester.tap(find.text('Jetzt bereitstellen'));
    await tester.pump();
    expect(find.textContaining('Sicherung wird erstellt'), findsOneWidget);
    await tester.tap(find.text('Jetzt bereitstellen'));
    await tester.pump(const Duration(seconds: 15));
    expect(backup.bereitstellungen, 1);
    expect(backup.abfragen, 1);
    backup.lauf!.complete();
    await tester.pumpAndSettle();
    expect(backup.abfragen, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('macht fehlende Statusauskunft sichtbar', (tester) async {
    backup.fehler = true;
    await zeigen(tester);
    expect(find.textContaining('Status nicht prüfbar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('erklärt den Unterschied zwischen Ablage und OneDrive-Upload', (
    tester,
  ) async {
    await zeigen(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        'Einen abgeschlossenen OneDrive-Upload kann die App nicht bestätigen',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Immer auf diesem Gerät behalten'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('bleibt bei schmalem Fenster und großer Schrift ohne Überlauf', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(body: SynchronisationsLeiste()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
