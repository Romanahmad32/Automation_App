import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/backup/domain/entities/letzte_sicherung.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/widgets/sicherungs_stand_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_doubles.dart';

/// Der Satz im Reiter „Datensicherung" (§7.2, #112): Zusätzlich zum Zeitpunkt
/// der letzten Sicherung soll er sagen, wie viele Archive dieses Rechners
/// liegen und wie weit die Historie zurückreicht — sonst bliebe unsichtbar,
/// dass die gestaffelte Aufbewahrung überhaupt etwas vorhält.
void main() {
  const ordner = r'C:\Ablage';

  UebergabeStand mitLauf({
    required bool gelungen,
    String? meldung,
    int eigeneArchive = 0,
    DateTime? aeltestesArchiv,
  }) => UebergabeStand(
    ablageOrdner: ordner,
    letzteSicherung: LetzteSicherung(
      zeitpunkt: DateTime.now().subtract(const Duration(hours: 1)),
      gelungen: gelungen,
      meldung: meldung,
    ),
    eigeneArchive: eigeneArchive,
    aeltestesArchiv: aeltestesArchiv,
  );

  test('ohne Ablageordner nennt sie die Einrichtung, keinen Archivsatz', () {
    final ergebnis = SicherungsStandZeile.satz(const UebergabeStand());

    expect(ergebnis, contains('Nicht eingerichtet'));
    expect(ergebnis, isNot(contains('dieses Rechners')));
  });

  test('nach einem Fehlschlag steht der Grund da, kein Archivsatz', () {
    final ergebnis = SicherungsStandZeile.satz(
      mitLauf(
        gelungen: false,
        meldung: 'Der Ordner ist nicht erreichbar.',
        eigeneArchive: 5,
      ),
    );

    expect(ergebnis, contains('Zuletzt fehlgeschlagen'));
    expect(ergebnis, contains('Der Ordner ist nicht erreichbar.'));
    expect(ergebnis, isNot(contains('dieses Rechners')));
  });

  test('ohne eigene Archive bleibt der Satz ohne Zusatz', () {
    final ergebnis = SicherungsStandZeile.satz(
      mitLauf(gelungen: true, eigeneArchive: 0),
    );

    expect(ergebnis, endsWith('nach $ordner.'));
    expect(ergebnis, isNot(contains('dieses Rechners')));
  });

  test('bei genau einem Archiv steht die Einzahl da', () {
    final ergebnis = SicherungsStandZeile.satz(
      mitLauf(gelungen: true, eigeneArchive: 1),
    );

    expect(ergebnis, endsWith('1 Sicherung dieses Rechners.'));
  });

  test('bei mehreren Archiven steht Anzahl und ältestes Datum da', () {
    final ergebnis = SicherungsStandZeile.satz(
      mitLauf(
        gelungen: true,
        eigeneArchive: 27,
        aeltestesArchiv: DateTime(2026, 3, 12),
      ),
    );

    expect(
      ergebnis,
      endsWith('27 Sicherungen dieses Rechners, älteste vom 12.03.2026.'),
    );
  });

  testWidgets('zeigt den Archivsatz in der Zeile', (tester) async {
    final stand = mitLauf(
      gelungen: true,
      eigeneArchive: 3,
      aeltestesArchiv: DateTime.now().subtract(const Duration(days: 40)),
    );
    getIt.registerSingleton<BackupRepository>(BackupDouble(stand));
    addTearDown(getIt.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SicherungsStandZeile())),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('3 Sicherungen dieses Rechners'),
      findsOneWidget,
    );
  });
}
