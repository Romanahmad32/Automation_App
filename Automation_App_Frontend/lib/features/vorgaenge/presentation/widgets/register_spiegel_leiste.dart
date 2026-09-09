import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:flutter/material.dart';

/// Der Zustand des Register-Spiegels unter der Tabelle (§6.2): wann zuletzt
/// geschrieben wurde und wohin.
///
/// Hier steht, was **dauerhaft** gilt — nicht, was gerade schiefging. Ein
/// fehlgeschlagener Lauf meldet sich als flüchtige Meldung oben rechts
/// (`RegisterSpiegelMeldung`), wie jeder andere Fehlschlag der App auch: Am Fuß
/// der Seite, unter tausenden Zeilen, hat ihn niemand gelesen, der eben oben
/// auf den Knopf gedrückt hat.
///
/// Der wichtigste Fall hier ist die Konfliktkopie. Sie heißt, dass jemand die
/// Datei unterwegs bearbeitet hat und der Synchronisierungsdienst nicht
/// zusammenführen konnte — ab da gäbe es zwei Register, und das ist genau die
/// Lage, aus der die Kanzlei heraus will. Sie ist eine Lage und kein Ereignis,
/// und steht deshalb hier und nicht in einer Meldung, die vorbeizieht.
///
/// **„PDF läuft" ist kein Fehler** (§6.2 „Word sofort, PDF nachgezogen"):
/// Solange [RegisterSpiegelErgebnis.pdfLaeuft] gilt, steht hier, dass die
/// Word-Datei liegt und das PDF noch entsteht — nicht, dass eines fehle
/// ([RegisterSpiegelErgebnis.pdfFehler] bleibt in diesem Fall ungezeigt, auch
/// wenn er zufällig gesetzt wäre). Der `RegisterSpiegelCubit` trägt den
/// Zustand über den Hub `/hubs/register` nach, sobald die Umwandlung fertig
/// ist — diese Leiste selbst fragt nicht nach.
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
        // Solange ein PDF entsteht, fehlt keins — beide Zustände schließen
        // sich aus (§6.2 „Solange kein neues PDF liegt, liegt auch kein
        // altes"), die Reihenfolge hier sichert das defensiv mit ab.
        if (stand.pdfLaeuft)
          _zeile(
            theme,
            Icons.hourglass_top_outlined,
            'Die Word-Datei liegt, das PDF entsteht noch — kommt von selbst '
            'nach.',
            farben.outline,
          )
        else if (stand.pdfFehler != null)
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
        _standzeile(theme, farben),
      ],
    );
  }

  Widget _standzeile(ThemeData theme, ColorScheme farben) {
    // Nach einem Fehlschlag steht hier nur, dass nichts geschrieben wurde —
    // warum, sagt die Meldung oben rechts. Ein Pfad aus dem letzten
    // erfolgreichen Lauf stünde hier sonst wie ein frisches Ergebnis.
    if (stand.fehler != null) {
      return _zeile(
        theme,
        Icons.cloud_off_outlined,
        'Zuletzt nicht geschrieben.',
        farben.outline,
      );
    }

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
