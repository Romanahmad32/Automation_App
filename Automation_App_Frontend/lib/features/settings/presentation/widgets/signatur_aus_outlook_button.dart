import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/signatur_auswahl_dialog.dart';
import 'package:flutter/material.dart';

/// Liest die in Outlook eingerichtete Signatur (§4.7) — statt sie abtippen zu
/// lassen.
///
/// Gelesen wird beides: Outlooks Nur-Text-Fassung und, falls vorhanden, die
/// formatierte samt Bildangaben. Das Einlesen erledigt der Dienst; die App
/// schickt nur den Namen. Die Bilder dürfen 25 MB groß sein und gehören ins
/// Dateisystem — sie durch die Oberfläche zu schleifen, nur damit sie von dort
/// zurückkommen, wären drei Stellen mehr, an denen etwas verlorengeht.
///
/// **Gelesen, nicht gespeichert** (geändert am 02.09.2026). Vorher schrieb
/// dieser Knopf sofort in die Einstellungen: Wer eine Signatur aus der Liste
/// wählte, hatte sie damit gewechselt — samt gelöschter Bilder der bisherigen,
/// ohne je auf „Speichern" gedrückt zu haben. Geschrieben wird jetzt beim
/// Speichern der Seite.
class SignaturAusOutlookButton extends StatefulWidget {
  /// Name und gelesener Stand der gewählten Signatur. Der Name geht mit, weil
  /// die Übernahme beim Speichern ihn braucht — der Dienst liest dann erneut.
  final void Function(String name, SignaturStand stand) onGelesen;

  final bool aktiv;

  const SignaturAusOutlookButton({
    super.key,
    required this.onGelesen,
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

      final stand = await zugang.leseSignatur(gewaehlt.name);
      if (!mounted) return;
      widget.onGelesen(gewaehlt.name, stand);
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
