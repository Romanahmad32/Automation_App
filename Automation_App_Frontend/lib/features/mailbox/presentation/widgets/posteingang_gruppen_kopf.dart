import 'package:automation_app/features/mailbox/presentation/utils/posteingang_tagesgruppen.dart';
import 'package:flutter/material.dart';

/// Die Gliederungszeile vor jeder Tagesgruppe der Posteingangsliste — getönte
/// Fläche und Versalien, wie die Jahreszeile im Register
/// (`register_jahres_zeile.dart`), aber mit Tagesbeschriftung statt Jahrzahl.
class PosteingangGruppenKopf extends StatelessWidget {
  const PosteingangGruppenKopf({super.key, required this.tag});

  /// Der Kalendertag der Gruppe (Tagesanfang, siehe
  /// `PosteingangTagesgruppe.tagVon`).
  final DateTime tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        posteingangTagesbeschriftung(tag).toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
