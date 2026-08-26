import 'dart:io';

import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/mail_versenden_button.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/versand_stand_zeile.dart';
import 'package:flutter/material.dart';

/// Bestätigungsdialog für den Vorgangsabschluss (§4.8).
///
/// Der Abschluss ist bewusst ein **eigener** Schritt: Er hängt nicht am
/// Versand, sondern an der Entscheidung des Anwalts, dass der Auftrag erledigt
/// ist. Deshalb bleibt das Häkchen — es ist nur schon gesetzt und begründet,
/// wenn die App selbst gesendet hat, und von Hand zu setzen, wenn der Anwalt
/// außerhalb der App gesendet hat. Erst danach zählt die Auftragsnummer hoch.
///
/// Liefert `true` (per `Navigator.pop`), wenn abgeschlossen werden soll.
class VorgangAbschliessenDialog extends StatefulWidget {
  final Vorgang vorgang;
  final Mandant? mandant;

  /// Versand, der vor dem Öffnen des Dialogs schon gelaufen ist.
  final EmailVersandErgebnis? bereitsVersendet;

  /// Wird gerufen, wenn aus diesem Dialog heraus gesendet wurde — damit der
  /// Speicherschritt denselben Stand zeigt.
  final ValueChanged<EmailVersandErgebnis> onVersendet;

  const VorgangAbschliessenDialog({
    super.key,
    required this.vorgang,
    required this.onVersendet,
    this.mandant,
    this.bereitsVersendet,
  });

  @override
  State<VorgangAbschliessenDialog> createState() =>
      _VorgangAbschliessenDialogState();
}

class _VorgangAbschliessenDialogState extends State<VorgangAbschliessenDialog> {
  EmailVersandErgebnis? _versand;
  bool _versandBestaetigt = false;

  @override
  void initState() {
    super.initState();
    _versand = widget.bereitsVersendet;
    _versandBestaetigt = _versand != null;
  }

  void _versandUebernehmen(EmailVersandErgebnis ergebnis) {
    setState(() {
      _versand = ergebnis;
      _versandBestaetigt = true;
    });
    widget.onVersendet(ergebnis);
  }

  /// Zeigt das abgelegte Dokument im Explorer (markiert) — für den Anwalt, der
  /// außerhalb der App senden will.
  void _zeigeDokumentImOrdner() {
    final pfad = widget.vorgang.dokumentPfad;
    if (pfad == null) return;
    Process.run('explorer', ['/select,', pfad]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hatDokument = widget.vorgang.dokumentPfad != null;

    return AlertDialog(
      title: const Text('Vorgang abschließen?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Der Vorgang „${widget.vorgang.referenz}" wird als erledigt '
              'markiert und ins Sachgebiete-Register aufgenommen. Die laufende '
              'Auftragsnummer wird für den nächsten Auftrag um eins '
              'hochgezählt.',
            ),
            const SizedBox(height: 16),
            VersandStandZeile(versand: _versand),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MailVersendenButton(
                  vorgang: widget.vorgang,
                  mandant: widget.mandant,
                  bereitsVersendet: _versand,
                  onVersendet: _versandUebernehmen,
                ),
                OutlinedButton.icon(
                  onPressed: hatDokument ? _zeigeDokumentImOrdner : null,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Dokument im Ordner zeigen'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _versandBestaetigt,
              onChanged: (wert) =>
                  setState(() => _versandBestaetigt = wert ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Die E-Mail mit dem Schreiben wurde versendet.',
              ),
              subtitle: _versand == null
                  ? Text(
                      'Auch außerhalb der App versendet? Dann hier bestätigen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _versandBestaetigt
              ? () => Navigator.pop(context, true)
              : null,
          child: const Text('Abschließen'),
        ),
      ],
    );
  }
}
