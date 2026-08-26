import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/signatur_auswahl_dialog.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die Signatur unter dem Mailtext beim Direktversand (§4.7) — mit dem Knopf,
/// der sie aus dem Mailprogramm übernimmt, statt sie abtippen zu lassen.
///
/// Outlook pflegt zu jeder Signatur eine Nur-Text-Fassung; genau die wird
/// gelesen. Danach hängt der Versand nicht mehr an Outlook: Die Signatur steht
/// in den Einstellungen und ist hier auch änderbar.
class MailSignaturField extends StatefulWidget {
  const MailSignaturField({super.key});

  @override
  State<MailSignaturField> createState() => _MailSignaturFieldState();
}

class _MailSignaturFieldState extends State<MailSignaturField> {
  bool _laedt = false;

  Future<void> _ausOutlook(AbstractControl<String> control) async {
    setState(() => _laedt = true);
    final melder = ScaffoldMessenger.of(context);

    try {
      final gefunden = await getIt<EmailVersandRepository>()
          .ladeOutlookSignaturen();
      if (!mounted) return;

      if (gefunden.isEmpty) {
        melder.showSnackBar(
          const SnackBar(
            content: Text(
              'In Outlook ist auf diesem Rechner keine Signatur eingerichtet. '
              'Sie lässt sich hier auch von Hand eintragen.',
            ),
          ),
        );
        return;
      }

      final gewaehlt = await SignaturAuswahlDialog.zeigen(context, gefunden);
      if (gewaehlt == null) return;

      control.value = gewaehlt.text;
      control.markAsDirty();
      melder.showSnackBar(
        SnackBar(
          content: Text(
            'Signatur „${gewaehlt.name}" übernommen. Noch speichern nicht '
            'vergessen.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      melder.showSnackBar(
        SnackBar(content: Text('Die Signaturen ließen sich nicht lesen: $e')),
      );
    } finally {
      if (mounted) setState(() => _laedt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveValueListenableBuilder<String>(
      formControlName: 'mailSignatur',
      builder: (context, control, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ReactiveTextField<String>(
              formControlName: 'mailSignatur',
              minLines: 4,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Signatur',
                alignLabelWithHint: true,
                hintText:
                    'Steht unter jedem Mailtext, den die App selbst versendet.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _laedt ? null : () => _ausOutlook(control),
                icon: _laedt
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('Aus Outlook übernehmen'),
              ),
            ),
          ],
        );
      },
    );
  }
}
