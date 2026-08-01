import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Schalter für SSL/TLS direkt beim Verbindungsaufbau (Port 993) vs. STARTTLS.
class MailboxSslSwitch extends StatelessWidget {
  const MailboxSslSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ReactiveValueListenableBuilder<bool>(
      formControlName: 'useSsl',
      builder: (context, control, _) {
        final useSsl = control.value ?? true;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: useSsl,
          onChanged: (v) => control.value = v,
          title: const Text('SSL/TLS direkt beim Verbinden (Port 993)'),
          subtitle: Text(
            useSsl
                ? 'Empfohlen für Gmail.'
                : 'STARTTLS wird verwendet, sofern der Server es anbietet.',
          ),
        );
      },
    );
  }
}
