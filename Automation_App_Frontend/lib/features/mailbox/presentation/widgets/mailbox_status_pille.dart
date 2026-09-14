import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_status_darstellung.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/status_pille.dart';
import 'package:flutter/material.dart';

/// Kompakte Fassung von `MailboxStatusBanner` für die Kopfzeile
/// (`SeitenAppBar.aktionen`, Issue #134): Icon + [StatusPille] statt eines
/// breiten Bandes. Zustand und Farbe kommen aus [MailboxStatusDarstellung];
/// der ausführliche Wortlaut (Modus, letzter Empfang bzw. Fehlermeldung)
/// steht im Tooltip statt fest auf der Fläche.
class MailboxStatusPille extends StatelessWidget {
  final MailboxStatus status;

  /// Ein von außen gemeldeter Fehler (z. B. beim Laden der Trefferliste) —
  /// geht wie im Banner jeder anderen Zustandsermittlung vor.
  final String? error;

  const MailboxStatusPille({super.key, required this.status, this.error});

  @override
  Widget build(BuildContext context) {
    final darstellung = MailboxStatusDarstellung.von(
      status,
      Theme.of(context).colorScheme,
      error: error,
    );

    return Tooltip(
      message: darstellung.langtext,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(darstellung.icon, size: 16, color: darstellung.accent),
          const SizedBox(width: 6),
          StatusPille(text: darstellung.kurztext, farbe: darstellung.accent),
        ],
      ),
    );
  }
}
