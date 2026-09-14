import 'package:automation_app/core/general_widgets/gerundeter_kasten.dart';
import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:flutter/material.dart';

/// Die Vorschlagskarte über der Aktionsleiste (Issue #134): „Vermutlich zu
/// Vorgang …" bzw. „Vorgang …", je nach [Vorgangsbezug.sicherheit].
///
/// Zeigt **nur einen Vorschlag** — sie ändert nichts am Vorgang. Der Anwalt
/// entscheidet über [onZumVorgang] (springt in den Tab „Vorgänge") oder
/// [onNichtZuordnen] (blendet die Karte nur für diese Sitzung aus, §4.3).
/// Ob die Karte überhaupt erscheint — Bezug vorhanden **und** nicht
/// unterdrückt —, entscheidet der Aufrufer: Er reicht [bezug] nur, wenn
/// beides zutrifft.
class PosteingangVorschlagKarte extends StatelessWidget {
  const PosteingangVorschlagKarte({
    super.key,
    required this.bezug,
    required this.onZumVorgang,
    required this.onNichtZuordnen,
  });

  final Vorgangsbezug bezug;
  final VoidCallback onZumVorgang;
  final VoidCallback onNichtZuordnen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = SoftTone.fromAccent(
      theme.colorScheme.primary,
      theme.colorScheme,
    );
    final vorgang = bezug.vorgang;
    final sicher = bezug.sicherheit == BezugSicherheit.sicher;
    final titel = sicher
        ? 'Vorgang ${vorgang.referenz}'
        : 'Vermutlich zu Vorgang ${vorgang.referenz}';
    final untertitel = [
      if ((vorgang.mandantName ?? '').trim().isNotEmpty)
        vorgang.mandantName!.trim(),
      if ((vorgang.kennzeichen ?? '').trim().isNotEmpty)
        vorgang.kennzeichen!.trim(),
    ].join(' · ');

    return GerundeterKasten(
      farbe: soft.background,
      randfarbe: soft.border,
      rundung: 16,
      polsterung: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: soft.foreground,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (untertitel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              untertitel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: soft.foreground,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Grund: ${bezug.grund}',
            style: theme.textTheme.bodySmall?.copyWith(color: soft.foreground),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: onZumVorgang,
                child: const Text('Zum Vorgang'),
              ),
              Tooltip(
                message:
                    'Ändert nichts am Vorgang — blendet den Vorschlag nur '
                    'für diese Sitzung aus.',
                child: TextButton(
                  onPressed: onNichtZuordnen,
                  child: const Text('Nicht zuordnen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
