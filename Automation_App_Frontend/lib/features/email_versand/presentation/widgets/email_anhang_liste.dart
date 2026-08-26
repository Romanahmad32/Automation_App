import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Die Anhänge der Mail (§4.7): Das Anspruchsschreiben ist vorausgewählt,
/// weitere Dateien aus dem Fall-Ordner lassen sich anklicken (Fotos, Gutachten,
/// Rechnungen), und alles Übrige kommt über die Dateiauswahl dazu.
///
/// Angezeigt wird der Dateiname, im Tooltip der volle Pfad — in einer Zeile mit
/// vollem Pfad erkennt niemand, ob da das Schreiben oder das Gutachten hängt.
class EmailAnhangListe extends StatefulWidget {
  final List<String> anhangPfade;

  /// Dateien aus dem Fall-Ordner des Vorgangs, die noch nicht angehängt sind.
  final List<String> ausDerAkte;

  final ValueChanged<String> onHinzufuegen;
  final ValueChanged<String> onEntfernen;
  final bool aktiv;

  const EmailAnhangListe({
    super.key,
    required this.anhangPfade,
    required this.onHinzufuegen,
    required this.onEntfernen,
    this.ausDerAkte = const [],
    this.aktiv = true,
  });

  @override
  State<EmailAnhangListe> createState() => _EmailAnhangListeState();
}

class _EmailAnhangListeState extends State<EmailAnhangListe> {
  /// Dateigröße je Pfad, einmal gelesen statt bei jedem Neubau. Das Formular
  /// baut bei jedem Tastendruck neu — ein `lengthSync` je Anhang und Anschlag
  /// wäre Plattenzugriff im Takt der Tastatur.
  Map<String, String> _groessen = const {};

  @override
  void initState() {
    super.initState();
    _groessenLesen();
  }

  @override
  void didUpdateWidget(EmailAnhangListe alt) {
    super.didUpdateWidget(alt);
    if (!listEquals(alt.anhangPfade, widget.anhangPfade)) _groessenLesen();
  }

  void _groessenLesen() {
    _groessen = {
      for (final pfad in widget.anhangPfade)
        pfad: AnhangDarstellung.groesse(pfad),
    };
  }

  Future<void> _dateiWaehlen() async {
    final auswahl = await FilePicker.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Dateien anhängen',
    );
    for (final datei in auswahl?.files ?? const <PlatformFile>[]) {
      final pfad = datei.path;
      if (pfad != null) widget.onHinzufuegen(pfad);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offen = widget.ausDerAkte
        .where((pfad) => !widget.anhangPfade.contains(pfad))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Anhänge', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        if (widget.anhangPfade.isEmpty)
          Text(
            'Keine Anhänge. Das Anspruchsschreiben gehört üblicherweise als PDF dazu.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final pfad in widget.anhangPfade)
                InputChip(
                  avatar: const Icon(Icons.attach_file, size: 18),
                  label: Text(AnhangDarstellung.name(pfad)),
                  tooltip: '$pfad\n${_groessen[pfad] ?? ''}',
                  onDeleted: widget.aktiv
                      ? () => widget.onEntfernen(pfad)
                      : null,
                ),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: widget.aktiv ? _dateiWaehlen : null,
              icon: const Icon(Icons.folder_open),
              label: const Text('Datei anhängen…'),
            ),
            for (final pfad in offen)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(AnhangDarstellung.name(pfad)),
                tooltip: 'Aus dem Fall-Ordner: $pfad',
                onPressed: widget.aktiv
                    ? () => widget.onHinzufuegen(pfad)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}
