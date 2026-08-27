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

  /// Aus der Outlook-Nachricht geholt und noch nicht angehängt. Getrennt von
  /// [ausDerAkte], weil nur diese sich verwerfen lassen: Der Fall-Ordner ist
  /// ein Bestand, den man nicht wegklickt — was aus Outlook kam, ist ein
  /// Griff, der auch danebengehen darf.
  final List<String> ausOutlook;

  /// Holt die Anhänge aus der Nachricht, die in Outlook gerade offen ist.
  final VoidCallback? onAusOutlook;

  /// Nimmt einen geholten Vorschlag wieder aus der Reihe.
  final ValueChanged<String>? onOutlookVerwerfen;

  /// True, solange Outlook danach gefragt wird.
  final bool holtAusOutlook;

  final bool aktiv;

  const EmailAnhangListe({
    super.key,
    required this.anhangPfade,
    required this.onHinzufuegen,
    required this.onEntfernen,
    required this.onUmbenennen,
    this.onAusOutlook,
    this.onOutlookVerwerfen,
    this.ausOutlook = const [],
    this.namen = const {},
    this.ausDerAkte = const [],
    this.holtAusOutlook = false,
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
    final ausAkte = ausDerAkte
        .where((pfad) => !anhangPfade.contains(pfad))
        .toList();
    final ausMail = ausOutlook
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
            // Der Weg für Dateien, die nur in einer Mail stecken und nirgends
            // auf der Platte liegen — Gutachten, Kostenvoranschlag, Fotos.
            if (onAusOutlook != null)
              OutlinedButton.icon(
                onPressed: aktiv && !holtAusOutlook ? onAusOutlook : null,
                icon: holtAusOutlook
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.move_to_inbox_outlined),
                label: Text(
                  holtAusOutlook
                      ? 'Fragt Outlook…'
                      : 'Aus der Outlook-Nachricht',
                ),
              ),
            // Aus Outlook geholt: anklicken haengt an, das Kreuz verwirft den
            // Vorschlag. Wer aus der falschen Nachricht geholt hat, soll die
            // Reihe wieder leer bekommen, ohne den Dialog zu schliessen.
            for (final pfad in ausMail)
              InputChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(AnhangDarstellung.name(pfad)),
                tooltip: 'Aus der Outlook-Nachricht: $pfad',
                onPressed: aktiv ? () => onHinzufuegen(pfad) : null,
                onDeleted: aktiv && onOutlookVerwerfen != null
                    ? () => onOutlookVerwerfen!(pfad)
                    : null,
                deleteIcon: const Icon(Icons.close, size: 16),
                deleteButtonTooltipMessage: 'Vorschlag verwerfen',
              ),
            for (final pfad in ausAkte)
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
