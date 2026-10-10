import 'package:automation_app/core/general_widgets/gerundeter_kasten.dart';
import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

/// Die formatierte Fassung einer Nachricht (Issue #134).
///
/// Der Dienst filtert `<script>`, aktive Attribute und jeden nachladenden
/// Verweis bereits heraus (`PosteingangHtmlFilter.FuerAnzeige`, Backend) —
/// diese Ansicht lädt trotzdem **kein** `<img>` nach: Jedes Bild wird über
/// [HtmlWidget.customWidgetBuilder] durch ein Platzhaltersymbol ersetzt,
/// statt die Standardabbildung ans Netz zu lassen. So bleibt die Zusage
/// „keine Netzwerkbilder" auch dann bestehen, wenn ein `src` einmal am
/// serverseitigen Filter vorbeikäme.
class PosteingangHtmlAnsicht extends StatelessWidget {
  const PosteingangHtmlAnsicht({
    super.key,
    required this.html,
    this.bilderBlockiert = false,
  });

  final String html;

  /// True, wenn der Dienst mindestens einen Verweis blockiert hat
  /// (Merkmal `data-blockiert` im gelieferten HTML) — der Aufrufer ermittelt
  /// das, damit diese Ansicht den Hinweis unabhängig vom eigenen Rendern
  /// zeigen kann.
  final bool bilderBlockiert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (bilderBlockiert) ...[
          GerundeterKasten(
            farbe: SoftTone.fromAccent(
              theme.colorScheme.outline,
              theme.colorScheme,
            ).background,
            rundung: 8,
            polsterung: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                // `Expanded` statt `MainAxisSize.min`: Bei „Am größten" und
                // schmalem Fenster braucht der Satz mehr als eine Zeile —
                // ohne Umbruchmöglichkeit lief die Zeile seitlich über statt
                // zu wachsen.
                Expanded(
                  child: Text(
                    'Externe Bilder werden nicht geladen.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        HtmlWidget(
          html,
          customWidgetBuilder: (element) => element.localName == 'img'
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          onErrorBuilder: (_, _, _) => const SizedBox.shrink(),
          onLoadingBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
