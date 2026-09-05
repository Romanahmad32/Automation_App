import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_reply_list.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Titelzeile "Erfasste Antworten" steht in einer `Row` ohne
/// `Expanded`/`Flexible`. In der echten Ansicht (`mailbox_inbox_view.dart`)
/// ist die Spalte fest auf 360 px begrenzt — hier nachgebaut, eingebettet in
/// ein 600 px breites Fenster, mit realistischen, langen Zentralruf-Daten
/// (lange Referenz, Versichererzeile, Zwischennachricht-Badge), um jedes
/// Überlaufrisiko der Liste bei "Am größten" (Issue #57) zu prüfen.
void main() {
  const status = MailboxStatus(
    enabled: true,
    configured: true,
    connected: true,
    idleSupported: true,
    lastConnectedAt: null,
    lastReplyAt: null,
    lastError: null,
    receivedCount: 3,
    pendingCount: 3,
  );

  final replies = [
    ReceivedReply(
      id: '1',
      receivedAt: DateTime(2026, 9, 5, 14, 32),
      subject: 'Auskunft zu Ihrer Anfrage',
      from: 'zentralruf@gdv-dienstleistungs-gmbh.de',
      acknowledged: false,
      warnings: const ['Kennzeichen passt nicht zur Referenz'],
      data: const ZentralrufReplyData(
        referenz: '123/2026 K_HG-E 1427',
        versichererName: 'HUK-Coburg Allgemeine Versicherung AG',
      ),
    ),
    ReceivedReply(
      id: '2',
      receivedAt: DateTime(2026, 9, 4, 9, 15),
      subject: 'Zwischennachricht',
      from: 'zentralruf@gdv-dienstleistungs-gmbh.de',
      acknowledged: false,
      warnings: const [],
      data: const ZentralrufReplyData(
        referenz: '124/2026 K_M-AB 2026',
        versichererName: 'Allianz Versicherungs-Aktiengesellschaft',
        zwischennachricht: true,
      ),
    ),
    ReceivedReply(
      id: '3',
      receivedAt: DateTime(2026, 9, 3, 8, 0),
      subject: 'Negativauskunft',
      from: 'zentralruf@gdv-dienstleistungs-gmbh.de',
      acknowledged: false,
      warnings: const [],
      data: const ZentralrufReplyData(keinVersichererErmittelt: true),
    ),
  ];

  Future<void> zeigeListe(WidgetTester tester, {required double breite}) async {
    tester.view.physicalSize = Size(breite, 700);
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
          // 360 px: dieselbe feste Spaltenbreite wie in
          // `mailbox_inbox_view.dart` — die Liste steht dort nie auf voller
          // Fensterbreite.
          body: SizedBox(
            width: 360,
            child: MailboxReplyList(
              replies: replies,
              selectedId: null,
              manualSelected: false,
              loading: false,
              status: status,
              onSelect: (_) {},
              onManual: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'die Titelzeile "Erfasste Antworten" und die Trefferliste laufen bei '
    '"Am groessten" nicht ueber',
    (tester) async {
      await zeigeListe(tester, breite: 600);

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Die Titelzeile "Erfasste Antworten" steht in einer Row ohne '
            'Expanded/Flexible, ebenso die Zeilen der Trefferliste — bei "Am '
            'größten" und der 360 px schmalen Spalte kann das überlaufen.',
      );
    },
  );
}
