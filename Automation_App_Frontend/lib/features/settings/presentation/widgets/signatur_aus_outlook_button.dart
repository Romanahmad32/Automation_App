import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/signatur_auswahl_dialog.dart';
import 'package:flutter/material.dart';

/// Übernimmt die in Outlook eingerichtete Signatur (§4.7) — statt sie abtippen
/// zu lassen.
///
/// Übernommen wird beides: Outlooks Nur-Text-Fassung und, falls vorhanden, die
/// formatierte samt Bildern. Das eigentliche Einlesen erledigt der Dienst; die
/// App schickt nur den Namen. Die Bilder gehören ins Dateisystem, und die
/// HTML-Fassung ist zehntausende Zeichen groß — beides durch die Oberfläche zu
/// schleifen, nur damit es von dort zurückkommt, wären drei Stellen mehr, an
/// denen etwas verlorengeht.
class SignaturAusOutlookButton extends StatefulWidget {
  /// Der Stand, wie er nach der Übernahme gespeichert ist.
  final ValueChanged<SignaturStand> onUebernommen;

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
    final zugang = getIt<EmailVersandRepository>();

    try {
      final gefunden = await zugang.ladeOutlookSignaturen();
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

      final stand = await zugang.uebernimmSignatur(gewaehlt.name);
      if (!mounted) return;
      widget.onUebernommen(stand);
    } catch (e) {
      if (!mounted) return;
      melder.showSnackBar(
        SnackBar(
          content: Text(
            'Die Signatur ließ sich nicht lesen: ${ausnahmeText(e)}',
          ),
        ),
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
