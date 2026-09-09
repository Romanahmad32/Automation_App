import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/register_import/presentation/utils/register_import_anleitung.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Der Auftrag an den Erzeuger der Registerdatei, fertig zum Kopieren — mit
/// der Jahrgangs-Auswahl daneben.
///
/// Die Auswahl ist der Grund, warum es diesen Dialog gibt und nicht bloß einen
/// Knopf: Der Auftrag gilt genau einem Jahrgang, und welcher als Nächstes dran
/// ist, weiß der Anwalt (bzw. der Stand auf Tab 6, der ihn als
/// [vorgeschlagenerJahrgang] hereinreicht). Ohne die Auswahl müsste er den
/// Platzhalter im kopierten Text von Hand suchen und ersetzen — genau der
/// Handgriff, bei dem aus 2021 später 2022 wird und niemand es merkt.
class RegisterImportAnleitungDialog extends StatefulWidget {
  /// Der Jahrgang, der voreingestellt ist. Ohne Vorgabe das laufende Jahr
  /// minus eins: Das aktuelle Jahr ist im Word-Register noch nicht
  /// abgeschlossen.
  final int? vorgeschlagenerJahrgang;

  const RegisterImportAnleitungDialog({
    super.key,
    this.vorgeschlagenerJahrgang,
  });

  /// Wie viele Jahrgänge die Auswahl rückwärts anbietet. Das Register der
  /// Kanzlei beginnt 2018; die Spanne ist bewusst großzügig, damit ein älterer
  /// Bestand nicht an der Oberfläche scheitert.
  static const jahrgangsSpanne = 20;

  @override
  State<RegisterImportAnleitungDialog> createState() =>
      _RegisterImportAnleitungDialogState();
}

class _RegisterImportAnleitungDialogState
    extends State<RegisterImportAnleitungDialog> {
  late int _jahrgang =
      widget.vorgeschlagenerJahrgang ?? DateTime.now().year - 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aktuell = DateTime.now().year;
    final jahre = [
      for (var jahr = aktuell; jahr >= aktuell - _spanne; jahr--) jahr,
      if (_jahrgang > aktuell || _jahrgang < aktuell - _spanne) _jahrgang,
    ]..sort((a, b) => b.compareTo(a));

    return AlertDialog(
      title: const Text('Auftrag für den Erzeuger'),
      content: SizedBox(
        width: 620,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              'Ein Auftrag je Jahrgang. Wählen Sie den Jahrgang, kopieren Sie '
              'den Text und lassen Sie damit auf dem Kanzleirechner die Datei '
              'erzeugen.',
              style: theme.textTheme.bodyMedium,
            ),
            Row(
              spacing: 12,
              children: [
                DropdownButton<int>(
                  value: _jahrgang,
                  onChanged: (wert) =>
                      setState(() => _jahrgang = wert ?? _jahrgang),
                  items: [
                    for (final jahr in jahre)
                      DropdownMenuItem(value: jahr, child: Text('$jahr')),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _kopieren,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('Auftrag kopieren'),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: SelectableText(
                  RegisterImportAnleitung.textFuer(_jahrgang).trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  int get _spanne => RegisterImportAnleitungDialog.jahrgangsSpanne;

  Future<void> _kopieren() async {
    final bote = Rueckmeldung.von(context);
    await Clipboard.setData(
      ClipboardData(text: RegisterImportAnleitung.textFuer(_jahrgang).trim()),
    );
    bote.erfolg(
      'Auftrag für den Jahrgang $_jahrgang kopiert — auf dem Kanzleirechner '
      'einfügen und die Datei erzeugen lassen.',
    );
  }
}
