import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_status_pille.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/status_pille.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _verbunden = MailboxStatus(
  enabled: true,
  configured: true,
  connected: true,
  idleSupported: true,
  lastConnectedAt: null,
  lastReplyAt: null,
  lastError: null,
  receivedCount: 3,
  pendingCount: 0,
);

/// Überwachung ausgeschaltet — es kommt gar nichts an.
const _inaktiv = MailboxStatus(
  enabled: false,
  configured: true,
  connected: false,
  idleSupported: false,
  lastConnectedAt: null,
  lastReplyAt: null,
  lastError: null,
  receivedCount: 0,
  pendingCount: 0,
);

/// Verbunden, aber ohne Push (IDLE): Das Postfach wird in Abständen abgefragt.
const _abruf = MailboxStatus(
  enabled: true,
  configured: true,
  connected: true,
  idleSupported: false,
  lastConnectedAt: null,
  lastReplyAt: null,
  lastError: null,
  receivedCount: 0,
  pendingCount: 0,
);

const _keinZugang = MailboxStatus(
  enabled: true,
  configured: false,
  connected: false,
  idleSupported: false,
  lastConnectedAt: null,
  lastReplyAt: null,
  lastError: null,
  receivedCount: 0,
  pendingCount: 0,
);

const _unterbrochen = MailboxStatus(
  enabled: true,
  configured: true,
  connected: false,
  idleSupported: false,
  lastConnectedAt: null,
  lastReplyAt: null,
  lastError: 'Zeitüberschreitung',
  receivedCount: 0,
  pendingCount: 0,
);

/// Fünf Zustände, dieselben Farben wie `MailboxStatusBanner`: grün Verbunden
/// (mit Push oder im Abruf-Modus), outline Inaktiv (Überwachung aus), tertiär
/// Kein Zugang, error Fehler.
///
/// „Inaktiv" und „Abruf" auseinanderzuhalten ist der Punkt (Korrektur vom
/// 13.09.2026): Vorher hieß der ausgeschaltete Zustand „Abruf" und las sich
/// damit wie eine langsamere Betriebsart statt wie „es kommt nichts an".
void main() {
  Future<ColorScheme> pumpPille(
    WidgetTester tester, {
    required MailboxStatus status,
    String? error,
  }) async {
    late ColorScheme scheme;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            return Scaffold(
              body: MailboxStatusPille(status: status, error: error),
            );
          },
        ),
      ),
    );
    await tester.pump();
    return scheme;
  }

  StatusPille pilleWidget(WidgetTester tester) =>
      tester.widget<StatusPille>(find.byType(StatusPille));

  String tooltipText(WidgetTester tester) =>
      tester.widget<Tooltip>(find.byType(Tooltip)).message!;

  testWidgets('Verbunden: gruen, Text "Verbunden", Langtext im Tooltip', (
    tester,
  ) async {
    await pumpPille(tester, status: _verbunden);

    final pille = pilleWidget(tester);
    expect(pille.text, 'Verbunden');
    expect(pille.farbe, Colors.green);
    expect(tooltipText(tester), contains('Verbunden'));
    expect(tooltipText(tester), contains('Push/IDLE'));
  });

  testWidgets(
    'Inaktiv: outline-Farbe, Text "Inaktiv" bei ausgeschalteter Ueberwachung',
    (tester) async {
      final scheme = await pumpPille(tester, status: _inaktiv);

      final pille = pilleWidget(tester);
      expect(pille.text, 'Inaktiv');
      expect(pille.farbe, scheme.outline);
      expect(tooltipText(tester), contains('Überwachung ausgeschaltet'));
    },
  );

  testWidgets('Abruf: gruen, Text "Abruf" nur wenn verbunden, aber ohne Push', (
    tester,
  ) async {
    await pumpPille(tester, status: _abruf);

    final pille = pilleWidget(tester);
    expect(pille.text, 'Abruf');
    // Verbunden bleibt verbunden — nur die Zustellung ist langsamer.
    expect(pille.farbe, Colors.green);
    expect(tooltipText(tester), contains('Abruf-Modus'));
  });

  testWidgets(
    'Kein Zugang: tertiaer, Text "Kein Zugang" ohne Postfach-Zugang',
    (tester) async {
      final scheme = await pumpPille(tester, status: _keinZugang);

      final pille = pilleWidget(tester);
      expect(pille.text, 'Kein Zugang');
      expect(pille.farbe, scheme.tertiary);
      expect(tooltipText(tester), contains('Kein Postfach-Zugang hinterlegt'));
    },
  );

  testWidgets(
    'Fehler: error-Farbe, Text "Fehler" bei unterbrochener Verbindung',
    (tester) async {
      final scheme = await pumpPille(tester, status: _unterbrochen);

      final pille = pilleWidget(tester);
      expect(pille.text, 'Fehler');
      expect(pille.farbe, scheme.error);
      expect(tooltipText(tester), contains('Verbindung unterbrochen'));
    },
  );

  testWidgets(
    'Fehler: ein von aussen gemeldeter Fehler geht vor und steht woertlich '
    'im Tooltip',
    (tester) async {
      final scheme = await pumpPille(
        tester,
        status: _verbunden,
        error: 'Trefferliste konnte nicht geladen werden.',
      );

      final pille = pilleWidget(tester);
      expect(pille.text, 'Fehler');
      expect(pille.farbe, scheme.error);
      expect(tooltipText(tester), 'Trefferliste konnte nicht geladen werden.');
    },
  );
}
