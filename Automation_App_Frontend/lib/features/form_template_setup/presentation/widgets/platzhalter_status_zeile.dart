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
/// bzw. die leere Dateizeile schon alles.
class PlatzhalterStatusZeile extends StatelessWidget {
  final SlotPlaceholders zustand;

  const PlatzhalterStatusZeile({super.key, required this.zustand});

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
      case SlotPlaceholdersInitial():
      case SlotPlaceholdersLoaded():
        return const SizedBox.shrink();
    }
  }
}
