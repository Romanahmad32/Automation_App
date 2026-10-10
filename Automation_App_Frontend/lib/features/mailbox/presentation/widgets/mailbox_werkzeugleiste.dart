import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_button.dart';
import 'package:flutter/material.dart';

/// Die Werkzeugleiste über der Posteingangsliste (§4.3): die beiden
/// Handlungen, die nichts mit einer ausgewählten Nachricht zu tun haben —
/// eine neue Mail schreiben und eine Antwortmail von Hand einfügen.
///
/// Die Filterreihe steht **nicht** hier, sondern in `PosteingangListe`,
/// direkt über der Liste, die sie eingrenzt — zwei Chip-Reihen
/// untereinander waren ein Befund aus dem Review zu Issue #134
/// (`posteingang_view_test.dart` hielt das mit einem `.first` fest, statt
/// die Dopplung zu melden).
///
/// Löst die frühere `MailboxVersandLeiste` ab, die nur den Versandknopf trug
/// und ihn an der erfassten Zentralruf-Antwort ausrichtete. Seit der
/// Posteingang selbst die Liste ist, gehört der Bezug an die geöffnete
/// Nachricht (`PosteingangAktionsleiste`) und nicht mehr über die Liste.
///
/// Zustandslos: Sie meldet nur zurück, was gedrückt wurde. Ein `Wrap` statt
/// einer `Row`, damit bei „Am größten" (Issue #57) und schmalem Fenster die
/// Knöpfe umbrechen, statt seitlich überzulaufen.
class MailboxWerkzeugleiste extends StatelessWidget {
  const MailboxWerkzeugleiste({
    super.key,
    required this.onNeuLaden,
    required this.onManuellEinfuegen,
  });

  final VoidCallback onNeuLaden;
  final VoidCallback onManuellEinfuegen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            onPressed: onNeuLaden,
            tooltip: 'Posteingang neu laden',
            icon: const Icon(Icons.refresh),
          ),
          OutlinedButton.icon(
            onPressed: onManuellEinfuegen,
            icon: const Icon(Icons.content_paste_go, size: 18),
            label: const Text(
              'Antwort manuell einfügen',
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const EmailVersandButton(
            beschriftung: 'Neue E-Mail',
            beschriftungErneut: 'Neue E-Mail',
          ),
        ],
      ),
    );
  }
}
