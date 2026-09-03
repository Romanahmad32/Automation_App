import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:flutter/material.dart';

/// Warnfläche in der Mandanten-Übersicht: sagt vor dem Speichern, dass hier
/// kein zweiter Mandant entsteht, sondern der bestehende Registereintrag seinen
/// Namen verliert — und wie viele Vorgänge das mitnehmen.
///
/// Steht **über** der Feldliste und nicht darunter: Wer das erst nach „Name:
/// alt → neu" läse, hätte bis dahin eine gewöhnliche Aktualisierung vor sich zu
/// haben geglaubt und den Knopf womöglich schon gedrückt.
class MandantUmbenennungHinweis extends StatelessWidget {
  final MandantUmbenennung umbenennung;

  const MandantUmbenennungHinweis({super.key, required this.umbenennung});

  /// Ein leerer Name wird benannt statt als Lücke im Satz gezeigt — „wird
  /// umbenannt in „"" liest sich wie ein Anzeigefehler.
  static String namen(String wert) =>
      wert.trim().isEmpty ? '(leer)' : wert.trim();

  /// Was aus den Vorgängen am Eintrag wird — leer, solange keiner daran hängt.
  /// Eine Warnung vor Folgen, die es nicht gibt, macht die echte unglaubwürdig:
  /// Beim frisch angelegten Mandanten ist die Umbenennung wirklich harmlos.
  String get _folgeFuerVorgaenge {
    final anzahl = umbenennung.betroffeneVorgaenge;
    if (anzahl <= 0) return '';
    if (anzahl == 1) {
      return ' Der eine Vorgang, der daran hängt, zeigt danach auf den neuen '
          'Namen.';
    }
    return ' Alle $anzahl Vorgänge, die daran hängen, zeigen danach auf den '
        'neuen Namen.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: theme.colorScheme.onErrorContainer,
          ),
          Expanded(
            child: Text(
              'Der Registereintrag „${namen(umbenennung.alt)}" wird umbenannt '
              'in „${namen(umbenennung.neu)}".$_folgeFuerVorgaenge '
              'Ist ein anderer Mensch gemeint, oben „(neuer Mandant)" wählen '
              'statt diesen Eintrag zu ändern.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
