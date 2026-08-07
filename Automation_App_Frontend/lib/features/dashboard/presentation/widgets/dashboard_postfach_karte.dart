import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_antwort_zeile.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_karte.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_leer_hinweis.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_auswahl_signal.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_status_banner.dart';
import 'package:flutter/material.dart';

/// Karte „Unbearbeitete Antworten": die vom Postfach-Monitor erfassten, noch
/// nicht quittierten Zentralruf-Antworten. Oben der Verbindungsstatus der
/// Überwachung ([MailboxStatusBanner]) — steht dort „ausgeschaltet", ist eine
/// leere Liste eben kein „nichts zu tun", sondern ein Einrichtungshinweis.
class DashboardPostfachKarte extends StatelessWidget {
  final List<ReceivedReply> antworten;
  final MailboxStatus status;
  final String? fehler;

  /// Wie viele Treffer die Karte höchstens auflistet.
  final int maxAntworten;

  const DashboardPostfachKarte({
    super.key,
    required this.antworten,
    required this.status,
    required this.fehler,
    this.maxAntworten = 5,
  });

  /// Springt ins Postfach und öffnet dort genau diesen Treffer.
  void _oeffne(BuildContext context, ReceivedReply antwort) {
    getIt<MailboxAuswahlSignal>().setze(antwort.id);
    AutoTabsRouter.of(context).setActiveIndex(AppTabIndex.postfach);
  }

  @override
  Widget build(BuildContext context) {
    final sichtbar = antworten.take(maxAntworten).toList();

    return DashboardKarte(
      titel: 'Unbearbeitete Antworten',
      icon: Icons.mark_email_unread_outlined,
      umfang: sichtbar.length < antworten.length
          ? '${sichtbar.length} von ${antworten.length}'
          : null,
      aktionLabel: 'Zum Postfach',
      zielTab: AppTabIndex.postfach,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MailboxStatusBanner(status: status, error: fehler),
          if (sichtbar.isEmpty)
            const DashboardLeerHinweis(
              icon: Icons.inbox_outlined,
              text:
                  'Keine offenen Zentralruf-Antworten. Eingehende Antworten '
                  'erscheinen hier automatisch.',
            )
          else
            for (final (index, antwort) in sichtbar.indexed) ...[
              if (index > 0) const Divider(height: 1, indent: 16),
              DashboardAntwortZeile(
                antwort: antwort,
                onOeffnen: () => _oeffne(context, antwort),
              ),
            ],
        ],
      ),
    );
  }
}
