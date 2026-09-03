import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/outlook_hinweis_zeile.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_aus_outlook_button.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_entfernen_button.dart';
import 'package:flutter/material.dart';

/// Die zwei Handgriffe an der Signatur (§4.7): aus Outlook holen und ganz
/// entfernen.
///
/// **Umbrechend und nicht nebeneinander erzwungen.** Als `Row` mit `Spacer`
/// lief sie in engen Fenstern über den Rand — der Reiter steht in einem
/// Dialog, dessen Breite vom Fenster abhängt. `Wrap` legt den zweiten Knopf
/// darunter, statt einen Überlauf zu melden.
///
/// Fehlt das klassische Outlook, steht statt des Holen-Knopfes der Grund da —
/// über der Zeile und in ganzer Breite, denn es ist ein Satz und kein Knopf.
/// Entfernen bleibt trotzdem möglich: Was einmal übernommen wurde, muss auch
/// ohne Outlook wieder weggehen können.
class SignaturKnopfzeile extends StatelessWidget {
  final OutlookStand outlook;
  final bool aktiv;

  /// Name und gelesener Stand der gewählten Outlook-Signatur.
  final void Function(String name, SignaturStand stand) onGelesen;

  final VoidCallback onEntfernen;

  const SignaturKnopfzeile({
    super.key,
    required this.outlook,
    required this.onGelesen,
    required this.onEntfernen,
    this.aktiv = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (!outlook.steuerbar)
          OutlookHinweisZeile(
            stand: outlook,
            was: 'Die Signatur lässt sich nicht aus Outlook übernehmen',
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (outlook.steuerbar)
              SignaturAusOutlookButton(aktiv: aktiv, onGelesen: onGelesen),
            SignaturEntfernenButton(aktiv: aktiv, onEntfernen: onEntfernen),
          ],
        ),
      ],
    );
  }
}
