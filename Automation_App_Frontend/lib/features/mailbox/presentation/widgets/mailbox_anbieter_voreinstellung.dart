import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Füllt Host, Port und Verschlüsselung mit den Werten eines bekannten
/// Anbieters. Grund: Ein falsch abgetippter Servername ist der häufigste
/// Grund, warum die Überwachung stumm bleibt — und die Fehlermeldung dazu
/// kommt vom Server auf Englisch.
class MailboxAnbieterVoreinstellung extends StatelessWidget {
  const MailboxAnbieterVoreinstellung({super.key});

  /// Beide gängigen Anbieter hören auf Port 993 mit SSL; abweichende Fälle
  /// bleiben Handarbeit in den Feldern darunter.
  void uebernehmen(BuildContext context, String imapHost) {
    final form = ReactiveForm.of(context, listen: false) as FormGroup;
    form.patchValue({'host': imapHost, 'port': '993', 'useSsl': true});
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.bolt, size: 18),
            label: const Text('1&1 / IONOS'),
            tooltip: 'imap.ionos.de, Port 993, SSL',
            onPressed: () => uebernehmen(context, 'imap.ionos.de'),
          ),
          ActionChip(
            avatar: const Icon(Icons.bolt, size: 18),
            label: const Text('Gmail'),
            tooltip: 'imap.gmail.com, Port 993, SSL',
            onPressed: () => uebernehmen(context, 'imap.gmail.com'),
          ),
        ],
      ),
    );
  }
}
