import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Hauptschalter der Postfach-Überwachung mit erklärendem Untertext.
class MailboxEnabledSwitch extends StatelessWidget {
  const MailboxEnabledSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return ReactiveValueListenableBuilder<bool>(
      formControlName: 'enabled',
      builder: (context, control, _) {
        final enabled = control.value ?? false;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: (v) => control.value = v,
          title: const Text('Postfach automatisch überwachen'),
          subtitle: Text(
            enabled
                ? 'Eingehende Antworten werden automatisch erfasst.'
                : 'Die Überwachung ist ausgeschaltet.',
          ),
        );
      },
    );
  }
}
