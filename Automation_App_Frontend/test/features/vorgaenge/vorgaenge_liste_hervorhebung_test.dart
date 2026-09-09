import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/letzte_versaende_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_hervorhebung_signal.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgaenge_liste.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_verwaltung_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Der Sprung aus dem Register in die Vorgangsverwaltung (§6.2).
///
/// Ohne die Hervorhebung endet der Sprung vor einer Liste, in der alle
/// Kacheln gleich aussehen — der Anwalt hätte den Vorgang, den er eben
/// angeklickt hat, noch einmal zu suchen.
/// Antwortet auf jeden Abruf mit nichts.
///
/// Die Vorgangskachel fragt beim Aufbau nach den letzten Versänden
/// (`VorgangVersandZeile` → `LetzteVersaendeCubit`). Für diesen Test zählt
/// davon nichts — er sieht sich an, welche Kachel hervorgehoben ist. Vierzehn
/// Methoden von Hand nachzubauen, hieße diesen Test an den Vertrag von
/// email_versand zu binden; `noSuchMethod` hält ihn davon frei.
class LeererVersandPort implements EmailVersandRepository {
  @override
  dynamic noSuchMethod(Invocation aufruf) async => <VersandEintrag>[];
}

void main() {
  late VorgangHervorhebungSignal signal;

  Vorgang vorgang(String referenz) => Vorgang(
    referenz: referenz,
    mandantName: 'Max Mustermann',
    angefragtAm: DateTime(2026, 6, 20),
  );

  final bestand = [vorgang('01/26 C03'), vorgang('02/26 C03')];

  setUp(() {
    signal = VorgangHervorhebungSignal();
    getIt.registerSingleton<VorgangHervorhebungSignal>(signal);
    getIt.registerSingleton<LetzteVersaendeCubit>(
      LetzteVersaendeCubit(LeererVersandPort()),
    );
  });

  tearDown(getIt.reset);

  Future<void> zeigeListe(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VorgaengeListe(
            vorgaenge: bestand,
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool istHervorgehoben(WidgetTester tester, String referenz) => tester
      .widgetList<VorgangVerwaltungTile>(find.byType(VorgangVerwaltungTile))
      .firstWhere((kachel) => kachel.vorgang.referenz == referenz)
      .hervorgehoben;

  testWidgets('ohne Signal ist keine Kachel hervorgehoben', (tester) async {
    await zeigeListe(tester);

    expect(istHervorgehoben(tester, '01/26 C03'), isFalse);
    expect(istHervorgehoben(tester, '02/26 C03'), isFalse);
  });

  testWidgets('das Signal hebt genau die angesprungene Kachel hervor', (
    tester,
  ) async {
    await zeigeListe(tester);

    signal.setze('02/26 C03');
    await tester.pump();

    expect(istHervorgehoben(tester, '02/26 C03'), isTrue);
    expect(istHervorgehoben(tester, '01/26 C03'), isFalse);
  });

  /// Sonst bliebe der Rand für den Rest der Sitzung stehen und behauptete eine
  /// Auswahl, die längst keine mehr ist.
  testWidgets('die Hervorhebung geht nach einigen Sekunden wieder aus', (
    tester,
  ) async {
    await zeigeListe(tester);
    signal.setze('02/26 C03');
    await tester.pump();

    await tester.pump(VorgaengeListe.hervorhebungsdauer);
    await tester.pumpAndSettle();

    expect(istHervorgehoben(tester, '02/26 C03'), isFalse);
  });

  /// Der Konsument räumt das Signal ab. Bliebe es stehen, spränge die Liste
  /// beim nächsten Öffnen des Tabs erneut zu einer Zeile, die niemand mehr
  /// gemeint hat.
  testWidgets('das Signal ist nach der Verarbeitung leer', (tester) async {
    await zeigeListe(tester);

    signal.setze('01/26 C03');
    await tester.pump();

    expect(signal.pendingReferenz.value, isNull);
  });
}
