import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_drucker.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_hinweis.dart';
import 'package:flutter/material.dart';

/// Die Zeile über den Knöpfen des Vollmacht-Dialogs (§4.11, #164): wohin
/// „Drucken" geht, und was Windows über den Drucker meldet.
///
/// Ein gemeldetes Problem sperrt nichts — viele Drucker melden sich auch
/// offline als bereit, und umgekehrt. Es nennt den Ausweg „In Word öffnen".
/// Gesperrt ist „Drucken" nur ohne eingerichteten Drucker
/// (`VollmachtStand.druckbereit`); die Zeile sagt dann, warum.
class VollmachtDruckerZeile extends StatelessWidget {
  final VollmachtDrucker? drucker;

  const VollmachtDruckerZeile({super.key, required this.drucker});

  @override
  Widget build(BuildContext context) {
    final drucker = this.drucker;
    if (drucker == null) return const SizedBox.shrink();

    final farben = Theme.of(context).colorScheme;
    final name = drucker.name ?? 'unbekannt';
    return switch (drucker.zustand) {
      VollmachtDruckerZustand.bereit => VollmachtHinweis(
        icon: Icons.print_outlined,
        farbe: farben.onSurfaceVariant,
        text: 'Drucker: $name (Windows-Standard)',
      ),
      VollmachtDruckerZustand.keinDrucker => VollmachtHinweis(
        icon: Icons.print_disabled_outlined,
        farbe: farben.error,
        text:
            '${drucker.hinweis ?? 'Kein Standarddrucker eingerichtet.'} '
            '„Drucken" geht deshalb nicht — „In Word öffnen" bleibt.',
      ),
      _ => VollmachtHinweis(
        icon: Icons.print_disabled_outlined,
        text:
            'Drucker: $name — ${drucker.hinweis ?? 'Zustand unklar.'} '
            'Kommt nichts heraus, hilft „In Word öffnen".',
      ),
    };
  }
}
