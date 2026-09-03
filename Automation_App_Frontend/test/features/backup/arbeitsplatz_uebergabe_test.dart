import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/backup/domain/entities/letzte_sicherung.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_angebot.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_stand.dart';
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/widgets/arbeitsplatz_uebergabe_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'backup_doubles.dart';

/// Die Rückfrage beim Start (§7.2, #39).
///
/// Ein Sicherungsordner ohne sie wäre eine Falle: Man spielt montags im Büro
/// einen Stand von Freitag ein und überschreibt die Arbeit vom Wochenende.
/// Geprüft wird deshalb beides — dass die Frage kommt, wenn es etwas zu fragen
/// gibt, und dass sie **nicht** kommt (und nichts einspielt), wenn nicht.
void main() {
  final angebot = UebergabeAngebot(
    rechnername: 'BUERO-PC',
    zuletztGearbeitet: DateTime.now().subtract(const Duration(hours: 2)),
    gesichertAm: DateTime.now().subtract(const Duration(hours: 2)),
    sicherung: 'automation-BUERO-PC-20260901-1412.zip',
    programmfassung: '1.4.2',
  );

  BackupDouble zeige(UebergabeStand stand, {bool standWirft = false}) {
    final backup = BackupDouble(stand, standWirft: standWirft);
    getIt.registerSingleton<BackupRepository>(backup);
    addTearDown(getIt.reset);
    return backup;
  }

  Future<void> baueGate(WidgetTester tester) async {
    await tester.pumpWidget(
      ArbeitsplatzUebergabeGate(
        anwendungBauen: () =>
            const MaterialApp(home: Scaffold(body: Text('Die Anwendung'))),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('fragt, wenn am anderen Rechner ein neuerer Stand liegt', (
    tester,
  ) async {
    zeige(
      UebergabeStand(
        angebot: angebot,
        eigenerStandGesichertAm: DateTime.now().subtract(
          const Duration(days: 3),
        ),
      ),
    );

    await baueGate(tester);

    expect(find.textContaining('auf BUERO-PC gearbeitet'), findsOneWidget);
    expect(find.text('Diesen Stand übernehmen?'), findsOneWidget);
    expect(find.text('Die Anwendung'), findsNothing);
  });

  testWidgets('geht ohne Angebot und ohne Fehler wortlos durch', (
    tester,
  ) async {
    final backup = zeige(const UebergabeStand(ablageOrdner: r'C:\Ablage'));

    await baueGate(tester);

    expect(find.text('Die Anwendung'), findsOneWidget);
    expect(backup.uebernahmen, 0);
  });

  /// Der Start darf nicht daran hängen, in welchem Zustand der andere
  /// Arbeitsplatz ist. Kommt keine Auskunft, geht es weiter.
  testWidgets('geht auch durch, wenn die Auskunft nicht zu bekommen ist', (
    tester,
  ) async {
    zeige(const UebergabeStand(), standWirft: true);

    await baueGate(tester);

    expect(find.text('Die Anwendung'), findsOneWidget);
  });

  testWidgets('„Eigenen Stand behalten" spielt nichts ein', (tester) async {
    final backup = zeige(UebergabeStand(angebot: angebot));

    await baueGate(tester);
    await tester.tap(find.text('Eigenen Stand behalten'));
    await tester.pumpAndSettle();

    expect(backup.uebernahmen, 0, reason: 'sonst waere die Frage eine Farce');
    expect(find.text('Die Anwendung'), findsOneWidget);
  });

  testWidgets('„Stand übernehmen" spielt ein und geht dann weiter', (
    tester,
  ) async {
    final backup = zeige(UebergabeStand(angebot: angebot));

    await baueGate(tester);
    await tester.tap(find.text('Stand übernehmen'));
    await tester.pumpAndSettle();

    expect(backup.uebernahmen, 1);
    expect(find.text('Die Anwendung'), findsOneWidget);
  });

  /// Das Backend spielt alles oder nichts ein. Scheitert es, bleibt der
  /// Bildschirm stehen — der Anwalt kann es erneut versuchen oder seinen Stand
  /// behalten. Ihn hier in eine Anwendung mit ungewissem Bestand zu schicken,
  /// wäre die schlechtere Antwort.
  testWidgets('bleibt stehen, wenn die Übernahme scheitert', (tester) async {
    final backup = zeige(UebergabeStand(angebot: angebot))
      ..uebernahmeWirft = StateError('Archiv nicht lesbar');

    await baueGate(tester);
    await tester.tap(find.text('Stand übernehmen'));
    await tester.pumpAndSettle();

    expect(backup.uebernahmen, 1);
    expect(find.text('Die Anwendung'), findsNothing);
    expect(
      find.textContaining('hat sich nichts geändert'),
      findsOneWidget,
      reason: 'der eigene Stand ist unberuehrt — das muss dastehen',
    );
  });

  /// Gesichert wird beim Beenden, wenn niemand mehr zusieht. Ein Fehlschlag
  /// kann den Anwalt deshalb nur beim nächsten Start erreichen — und danach
  /// nicht bei jedem weiteren wieder.
  testWidgets('meldet eine misslungene Sicherung und quittiert sie', (
    tester,
  ) async {
    final backup = zeige(
      UebergabeStand(
        ablageOrdner: r'C:\Ablage',
        letzteSicherung: LetzteSicherung(
          zeitpunkt: DateTime.now().subtract(const Duration(hours: 12)),
          gelungen: false,
          meldung: 'Der Ordner ist nicht erreichbar.',
        ),
      ),
    );

    await baueGate(tester);

    expect(
      find.text('Die automatische Sicherung ist fehlgeschlagen'),
      findsOneWidget,
    );
    expect(find.text('Der Ordner ist nicht erreichbar.'), findsOneWidget);

    await tester.tap(find.text('Verstanden'));
    await tester.pumpAndSettle();

    expect(backup.quittungen, 1);
    expect(find.text('Die Anwendung'), findsOneWidget);
  });

  testWidgets('eine quittierte Meldung hält den Start nicht mehr auf', (
    tester,
  ) async {
    zeige(
      UebergabeStand(
        ablageOrdner: r'C:\Ablage',
        letzteSicherung: LetzteSicherung(
          zeitpunkt: DateTime.now(),
          gelungen: false,
          meldung: 'Der Ordner ist nicht erreichbar.',
          fehlerQuittiert: true,
        ),
      ),
    );

    await baueGate(tester);

    expect(find.text('Die Anwendung'), findsOneWidget);
  });
}
