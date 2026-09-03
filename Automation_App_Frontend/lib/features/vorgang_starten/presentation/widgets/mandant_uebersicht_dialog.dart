import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_umbenennung_hinweis.dart';
import 'package:flutter/material.dart';

/// Zeigt vor dem Speichern eine kurze Übersicht, was am Mandanten angelegt
/// ([istNeu] = true) oder geändert würde, und lässt den Nutzer bestätigen oder
/// abbrechen (§1.3). Liefert `true` (bestätigt) oder `null`/`false`
/// (abgebrochen → nichts speichern).
///
/// Ist [umbenennung] gesetzt, geht es nicht um eine Korrektur am Eintrag,
/// sondern um seinen Namen: Titel, Warnfläche und Knopfbeschriftung wechseln
/// dann auf „umbenennen", damit die Rückfrage nicht harmloser aussieht als das,
/// was auf sie folgt (§5.1).
class MandantUebersichtDialog extends StatelessWidget {
  final bool istNeu;
  final List<MandantFeldDiff> zeilen;

  /// Die anstehende Umbenennung des Registereintrags — null, solange der Name
  /// bleibt.
  final MandantUmbenennung? umbenennung;

  const MandantUebersichtDialog({
    super.key,
    required this.istNeu,
    required this.zeilen,
    this.umbenennung,
  });

  static Future<bool?> zeige(
    BuildContext context, {
    required bool istNeu,
    required List<MandantFeldDiff> zeilen,
    MandantUmbenennung? umbenennung,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => MandantUebersichtDialog(
        istNeu: istNeu,
        zeilen: zeilen,
        umbenennung: umbenennung,
      ),
    );
  }

  IconData get _symbol {
    if (umbenennung != null) return Icons.warning_amber_outlined;
    return istNeu ? Icons.person_add_alt_1_outlined : Icons.edit_note_outlined;
  }

  String get _titel {
    if (umbenennung != null) return 'Mandanten umbenennen';
    return istNeu ? 'Neuen Mandanten anlegen' : 'Mandantendaten aktualisieren';
  }

  String get _beschriftung {
    if (umbenennung != null) return 'Umbenennen';
    return istNeu ? 'Anlegen' : 'Aktualisieren';
  }

  @override
  Widget build(BuildContext context) {
    final warnung = umbenennung;
    return AlertDialog(
      icon: Icon(_symbol),
      title: Text(_titel),
      // Scrollbar, weil die Warnfläche zu den bis zu sieben Feldzeilen kommt:
      // Auf einem schmalen Fenster liefe der Inhalt sonst über und der Anwalt
      // sähe die Zeile nicht mehr, wegen der er den Dialog liest.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (warnung != null) ...[
              MandantUmbenennungHinweis(umbenennung: warnung),
              const SizedBox(height: 12),
            ],
            Text(
              istNeu
                  ? 'Mit diesen Daten wird ein neuer Mandant im Register angelegt:'
                  : 'Folgende Daten werden beim Mandanten geändert:',
            ),
            const SizedBox(height: 12),
            for (final zeile in zeilen)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: MandantUebersichtZeile(zeile: zeile, istNeu: istNeu),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(_beschriftung),
        ),
      ],
    );
  }
}

/// Eine Zeile der Mandanten-Übersicht: „Label: Wert" bei Anlage,
/// „Label: alt → neu" bei Aktualisierung (leerer Altwert als „(leer)").
class MandantUebersichtZeile extends StatelessWidget {
  final MandantFeldDiff zeile;
  final bool istNeu;

  const MandantUebersichtZeile({
    super.key,
    required this.zeile,
    required this.istNeu,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fett = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: [
          TextSpan(text: '${zeile.label}: ', style: fett),
          if (istNeu)
            TextSpan(text: zeile.neu)
          else ...[
            TextSpan(
              text: zeile.alt.isEmpty ? '(leer)' : zeile.alt,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
                decorationColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const TextSpan(text: '  →  '),
            TextSpan(
              text: zeile.neu.isEmpty ? '(leer)' : zeile.neu,
              style: fett,
            ),
          ],
        ],
      ),
    );
  }
}
