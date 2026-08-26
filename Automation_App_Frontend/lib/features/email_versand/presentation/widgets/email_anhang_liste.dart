import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_anhang_chip.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Die Anhänge der Mail (§4.7): Das Anspruchsschreiben ist vorausgewählt,
/// weitere Dateien aus dem Fall-Ordner lassen sich anklicken (Fotos, Gutachten,
/// Rechnungen), und alles Übrige kommt über die Dateiauswahl dazu.
///
/// Jeder Anhang lässt sich öffnen und für die Mail umbenennen — siehe
/// [EmailAnhangChip].
class EmailAnhangListe extends StatelessWidget {
  final List<String> anhangPfade;

  /// Dateien aus dem Fall-Ordner des Vorgangs, die noch nicht angehängt sind.
  final List<String> ausDerAkte;

  /// Abweichender Dateiname je Pfad, wenn der Anwalt umbenannt hat.
  final Map<String, String> namen;

  final ValueChanged<String> onHinzufuegen;
  final ValueChanged<String> onEntfernen;

  /// (Pfad, neuer Name) — benennt nur für die Mail um, nicht auf Platte.
  final void Function(String pfad, String name) onUmbenennen;

  final bool aktiv;

  const EmailAnhangListe({
    super.key,
    required this.anhangPfade,
    required this.onHinzufuegen,
    required this.onEntfernen,
    required this.onUmbenennen,
    this.namen = const {},
    this.ausDerAkte = const [],
    this.aktiv = true,
  });

  Future<void> _dateiWaehlen() async {
    final auswahl = await FilePicker.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Dateien anhängen',
    );
    for (final datei in auswahl?.files ?? const <PlatformFile>[]) {
      final pfad = datei.path;
      if (pfad != null) onHinzufuegen(pfad);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offen = ausDerAkte
        .where((pfad) => !anhangPfade.contains(pfad))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Anhänge', style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        if (anhangPfade.isEmpty)
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
              for (final pfad in anhangPfade)
                EmailAnhangChip(
                  pfad: pfad,
                  name: namen[pfad] ?? AnhangDarstellung.name(pfad),
                  onUmbenennen: (name) => onUmbenennen(pfad, name),
                  onEntfernen: () => onEntfernen(pfad),
                  aktiv: aktiv,
                ),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: aktiv ? _dateiWaehlen : null,
              icon: const Icon(Icons.folder_open),
              label: const Text('Datei anhängen…'),
            ),
            for (final pfad in offen)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(AnhangDarstellung.name(pfad)),
                tooltip: 'Aus dem Fall-Ordner: $pfad',
                onPressed: aktiv ? () => onHinzufuegen(pfad) : null,
              ),
          ],
        ),
      ],
    );
  }
}
