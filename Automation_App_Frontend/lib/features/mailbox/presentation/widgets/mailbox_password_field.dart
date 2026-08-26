import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:flutter/material.dart';

/// Passwortfeld für den IMAP-Zugang: obscured; ist bereits eines gespeichert,
/// darf es leer bleiben (dann wird das gespeicherte beibehalten).
class MailboxPasswordField extends StatefulWidget {
  final bool alreadySet;

  const MailboxPasswordField({super.key, required this.alreadySet});

  @override
  State<MailboxPasswordField> createState() => _MailboxPasswordFieldState();
}

class _MailboxPasswordFieldState extends State<MailboxPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return GeneralTextField<String>(
      formControlName: 'appPassword',
      obscureText: _obscured,
      labelText: widget.alreadySet
          ? 'Passwort (gespeichert — leer lassen = unverändert)'
          : 'Passwort',
      inputDecoration: InputDecoration(
        helperText: widget.alreadySet
            ? 'Es ist bereits ein Passwort hinterlegt.'
            : '1&1/IONOS: Postfach-Passwort. Gmail: App-Passwort.',
        suffixIcon: IconButton(
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          tooltip: _obscured ? 'Anzeigen' : 'Verbergen',
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
