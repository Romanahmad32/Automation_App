import 'dart:io';

import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';

/// Bestätigungsdialog für den Vorgangsabschluss (§4.8). Solange der
/// E-Mail-Versand nicht in der App umgesetzt ist, schließt er die Lücke zwischen
/// „abschließen" und tatsächlichem Versand: Er öffnet auf Wunsch einen
/// E-Mail-Entwurf im Standard-Mailprogramm bzw. den Ablageordner des Dokuments
/// und lässt das Abschließen erst zu, wenn der Anwalt den Versand ausdrücklich
/// bestätigt hat — erst dann zählt die Auftragsnummer hoch.
///
/// Liefert `true` (per `Navigator.pop`), wenn abgeschlossen werden soll.
class VorgangAbschliessenDialog extends StatefulWidget {
  final Vorgang vorgang;

  const VorgangAbschliessenDialog({super.key, required this.vorgang});

  @override
  State<VorgangAbschliessenDialog> createState() =>
      _VorgangAbschliessenDialogState();
}

class _VorgangAbschliessenDialogState extends State<VorgangAbschliessenDialog> {
  bool _versandBestaetigt = false;

  /// Öffnet einen mailto-Entwurf im Standard-Mailprogramm. Direkt über
  /// rundll32 statt cmd/start, damit `&` in der Query nicht von der Shell
  /// interpretiert wird. Den Anhang muss der Anwalt selbst anfügen (mailto
  /// kann keine Anhänge); der Hinweis samt Dokumentpfad steht im Entwurf.
  void _oeffneEmailEntwurf() {
    final vorgang = widget.vorgang;
    final betreff = Uri.encodeComponent(
      'Anspruchsschreiben ${vorgang.referenz}',
    );
    final pfad = vorgang.dokumentPfad;
    final body = Uri.encodeComponent(
      pfad == null
          ? 'Bitte das Anspruchsschreiben als Anhang anfügen.'
          : 'Bitte das Anspruchsschreiben als Anhang anfügen:\n$pfad',
    );
    Process.run('rundll32', [
      'url.dll,FileProtocolHandler',
      'mailto:?subject=$betreff&body=$body',
    ]);
  }

  /// Zeigt das abgelegte Dokument im Explorer (markiert), damit es sich direkt
  /// in den E-Mail-Entwurf ziehen lässt.
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
            Text(
              'Das Versenden der E-Mail (§4.7) erfolgt noch manuell:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _oeffneEmailEntwurf,
                  icon: const Icon(Icons.outgoing_mail),
                  label: const Text('E-Mail-Entwurf öffnen'),
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
