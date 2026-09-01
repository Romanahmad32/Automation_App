import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:flutter/material.dart';

/// Der Zustand des Register-Spiegels unter der Tabelle (§6.2): wann zuletzt
/// geschrieben wurde, wohin, und was schiefging.
///
/// Der wichtigste Fall ist die Konfliktkopie. Sie heißt, dass jemand die Datei
/// unterwegs bearbeitet hat und der Synchronisierungsdienst nicht
/// zusammenführen konnte — ab da gäbe es zwei Register, und das ist genau die
/// Lage, aus der die Kanzlei heraus will. Deshalb steht sie hier als Warnung
/// und nicht als Nebensatz.
class RegisterSpiegelLeiste extends StatelessWidget {
  final RegisterSpiegelErgebnis stand;

  const RegisterSpiegelLeiste({super.key, required this.stand});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stand.fehler != null)
          _zeile(theme, Icons.error_outline, stand.fehler!, farben.error),
        if (stand.pdfFehler != null)
          _zeile(
            theme,
            Icons.picture_as_pdf_outlined,
            stand.pdfFehler!,
            farben.tertiary,
          ),
        if (stand.konfliktkopien.isNotEmpty)
          _zeile(
            theme,
            Icons.warning_amber_outlined,
            'Neben dem Register liegt eine Konfliktkopie '
            '(${stand.konfliktkopien.join(', ')}). Sie entsteht, wenn die Datei '
            'unterwegs bearbeitet wurde — gepflegt wird das Register in der App. '
            'Bitte die Kopie ansehen und danach löschen.',
            farben.error,
          ),
        if (stand.fehler == null) _erfolgszeile(theme, farben),
      ],
    );
  }

  Widget _erfolgszeile(ThemeData theme, ColorScheme farben) {
    final satz = switch (stand) {
      RegisterSpiegelErgebnis(geschrieben: true, docxPfad: final pfad?) =>
        'Geschrieben nach $pfad',
      RegisterSpiegelErgebnis(grund: final grund?) => grund,
      RegisterSpiegelErgebnis(docxPfad: final pfad?) =>
        'Zuletzt geschrieben nach $pfad',
      _ => 'Noch nicht geschrieben.',
    };
    final zeitpunkt = stand.geschriebenAm;
    final zusatz = zeitpunkt == null
        ? ''
        : ' · ${deutschesDatumMitUhrzeit(zeitpunkt)}';

    return _zeile(
      theme,
      Icons.cloud_done_outlined,
      '$satz$zusatz',
      farben.outline,
    );
  }

  Widget _zeile(ThemeData theme, IconData icon, String text, Color farbe) =>
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: farbe),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(color: farbe),
              ),
            ),
          ],
        ),
      );
}
