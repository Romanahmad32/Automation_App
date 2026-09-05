import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Statuszeile zeigt links den laufenden Text (bereits in `Expanded`) und
/// rechts, unbeschränkt, "Letzter Empfang: …" — bei "Am größten" (Issue #57)
/// und schmalem Fenster kann diese zweite Textgruppe die Zeile sprengen, weil
/// sie kein Flex-Kind ist und nicht schrumpfen kann.
void main() {
  Future<void> zeigeBanner(
    WidgetTester tester, {
    required double breite,
    required MailboxStatus status,
    String? error,
  }) async {
    tester.view.physicalSize = Size(breite, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        // Das echte, auf „Am größten" angehobene Theme (Issue #57) — sonst
        // bliebe der Test blind für den gemeldeten Überlauf.
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: Schriftstufe.amGroessten,
        ).light(),
        home: Scaffold(
          body: MailboxStatusBanner(status: status, error: error),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'die Statuszeile laeuft bei "Am groessten" und schmalem Fenster nicht '
    'ueber, wenn zusaetzlich der letzte Empfang angezeigt wird',
    (tester) async {
      const status = MailboxStatus(
        enabled: true,
        configured: true,
        connected: true,
        idleSupported: false,
        lastConnectedAt: null,
        lastReplyAt: null,
        lastError: null,
        receivedCount: 3,
        pendingCount: 1,
      );
      await zeigeBanner(
        tester,
        breite: 360,
        status: status.copyWithLastReplyAt(DateTime(2026, 9, 5, 14, 32)),
      );

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Der Text "Letzter Empfang: …" steht ohne Flexible neben dem '
            'bereits in Expanded gefassten Statustext — bei "Am größten" und '
            'schmalem Fenster lief die Zeile über.',
      );
    },
  );
}

extension on MailboxStatus {
  MailboxStatus copyWithLastReplyAt(DateTime value) => MailboxStatus(
    enabled: enabled,
    configured: configured,
    connected: connected,
    idleSupported: idleSupported,
    lastConnectedAt: lastConnectedAt,
    lastReplyAt: value,
    lastError: lastError,
    receivedCount: receivedCount,
    pendingCount: pendingCount,
  );
}
