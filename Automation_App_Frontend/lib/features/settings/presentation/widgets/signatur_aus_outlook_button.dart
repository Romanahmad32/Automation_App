import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/signatur_auswahl_dialog.dart';
import 'package:flutter/material.dart';

/// Holt die in Outlook eingerichtete Signatur und gibt die gewählte nach oben
/// (§4.7) — statt sie abtippen zu lassen.
///
/// Outlook pflegt zu jeder Signatur eine Nur-Text-Fassung; genau die wird
/// gelesen. Danach hängt nichts mehr an Outlook: Die Signatur steht in den
/// Einstellungen und ist dort auch von Hand änderbar.
class SignaturAusOutlookButton extends StatefulWidget {
  /// Die vom Anwalt gewählte Signatur. Übernommen, aber noch nicht gespeichert.
  final ValueChanged<OutlookSignatur> onUebernommen;

  final bool aktiv;

  const SignaturAusOutlookButton({
    super.key,
    required this.onUebernommen,
    this.aktiv = true,
  });

  @override
  State<SignaturAusOutlookButton> createState() =>
      _SignaturAusOutlookButtonState();
}

class _SignaturAusOutlookButtonState extends State<SignaturAusOutlookButton> {
  bool _laedt = false;

  Future<void> _holen() async {
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
      if (gewaehlt == null || !mounted) return;
      widget.onUebernommen(gewaehlt);
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
    return OutlinedButton.icon(
      onPressed: widget.aktiv && !_laedt ? _holen : null,
      icon: _laedt
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_outlined),
      label: const Text('Aus Outlook übernehmen'),
    );
  }
}
