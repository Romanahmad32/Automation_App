import 'package:flutter/material.dart';

/// Einheitlicher Seitenkopf aller Hauptseiten: das Symbol der Seite in einer
/// farbigen Kachel, links daran der Titel und darunter ein kurzer Untertitel,
/// der sagt, wofür die Seite da ist. Ein weicher Farbverlauf von links trennt
/// den Kopf sichtbar vom Inhalt, ohne laut zu wirken.
///
/// Ersetzt die bis dahin je Seite handgebaute [AppBar] mit zentriertem
/// Fettschrift-Titel — Symbol, Titeltext und Untertitel liegen damit an einer
/// Stelle und sehen auf jeder Seite gleich aus.
class SeitenAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Titel der Seite, identisch zur Beschriftung in der Seitenleiste.
  final String titel;

  /// Symbol der Seite — dasselbe wie in der Seitenleiste, damit der Anwalt
  /// Kopf und Navigationspunkt als dieselbe Seite erkennt.
  final IconData icon;

  /// Ein Satzteil, der den Zweck der Seite benennt. Null lässt die Zeile weg.
  final String? untertitel;

  /// Aktionen rechts im Kopf (z. B. `PageRefreshButton`).
  final List<Widget> aktionen;

  /// Optionaler Aufsatz unter dem Kopf, z. B. die `TabBar` der Einstellungen.
  final PreferredSizeWidget? bottom;

  /// Höhe der Kopfzeile selbst (ohne [bottom]).
  static const double hoehe = 76;

  const SeitenAppBar({
    super.key,
    required this.titel,
    required this.icon,
    this.untertitel,
    this.aktionen = const [],
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(hoehe + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    final istHell = theme.brightness == Brightness.light;

    return AppBar(
      toolbarHeight: hoehe,
      centerTitle: false,
      titleSpacing: 20,
      // Zarter Verlauf aus der Primärfarbe, der nach rechts ausläuft: er hebt
      // den Kopf vom Seiteninhalt ab, ohne ihn wie eine gefärbte Leiste
      // aussehen zu lassen.
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: const [0, 0.7],
            colors: [
              farben.primary.withValues(alpha: istHell ? 0.09 : 0.16),
              farben.primary.withValues(alpha: 0),
            ],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: farben.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: farben.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titel,
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (untertitel case final text?)
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: farben.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [...aktionen, const SizedBox(width: 12)],
      bottom: bottom,
    );
  }
}
