import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart';
import 'package:flutter/material.dart';

/// „Wird gelesen …" bzw. die Fehlermeldung zur Platzhalter-Erkennung **einer**
/// Word-Datei — sonst nichts.
///
/// Eigener Baustein, weil die Auskunft seit Stufe 3a an zwei Stellen gebraucht
/// wird: an der Dateikarte, wo der Anwalt gerade eine Datei gewählt hat und
/// wissen will, ob sie gelesen wurde, und im aufgeklappten
/// `PlatzhalterAbschnitt`, wo statt der Chips noch nichts dastünde. Vorher
/// hing beides in `TemplatePlaceholdersView` und wäre beim Trennen von Datei
/// und Chips entweder verloren gegangen oder zweimal dagestanden.
///
/// Geladen und „noch nichts geladen" sind beide still: Dann sagen die Chips
/// bzw. die leere Dateizeile schon alles. **Ausnahme ist [zeigtAnzahl]** — auf
/// der Auswahlseite einer neuen Vorlage stehen weder Chips noch Feldertabelle
/// daneben, und „nichts" sähe dort aus, als sei die Datei nicht gelesen
/// worden.
class PlatzhalterStatusZeile extends StatelessWidget {
  final SlotPlaceholders zustand;

  /// Ob eine fertig gelesene Datei ihre Zahl nennt („14 Platzhalter
  /// erkannt").
  ///
  /// Vorgabe false: An der Dateikarte des Editors und im aufgeklappten
  /// `PlatzhalterAbschnitt` steht die Zahl schon woanders (Stand-Karte, Chips),
  /// und zweimal dieselbe Zahl übereinander liest sich wie zwei Aussagen.
  /// True setzt die Auswahlseite (`VorlagenDateiKachel`), die sonst nach dem
  /// Lesen nichts zu berichten hätte.
  final bool zeigtAnzahl;

  const PlatzhalterStatusZeile({
    super.key,
    required this.zustand,
    this.zeigtAnzahl = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (zustand) {
      case SlotPlaceholdersLoading():
        // Der Text steht im `Expanded`, weil die Zeile seit Stufe 3a in einer
        // 400 px schmalen Spalte stehen kann — bei angehobener Schrift (Issue
        // #57) liefe sie sonst rechts aus der Karte.
        return const Row(
          spacing: 10,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            Expanded(child: Text('Platzhalter werden gelesen …')),
          ],
        );
      case SlotPlaceholdersError(message: final message):
        return Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        );
      case SlotPlaceholdersLoaded(placeholders: final erkannt) when zeigtAnzahl:
        return Row(
          spacing: 10,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            Expanded(child: Text(_erkannt(erkannt.length))),
          ],
        );
      case SlotPlaceholdersInitial():
      case SlotPlaceholdersLoaded():
        return const SizedBox.shrink();
    }
  }

  /// Null Platzhalter sind kein Fehler, aber auch keine Zahl, die man vorliest
  /// — eine Word-Datei ohne `{{…}}` ergibt eine Vorlage ohne Felder, und das
  /// benennt danach die Stand-Karte.
  String _erkannt(int anzahl) => switch (anzahl) {
    0 => 'Keine Platzhalter erkannt',
    1 => '1 Platzhalter erkannt',
    _ => '$anzahl Platzhalter erkannt',
  };
}
