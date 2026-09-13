import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/status_pille.dart';
import 'package:flutter/material.dart';

/// Eine Zeile des Bereichs „Gesendet" (§4.3) — spiegelbildlich zur
/// `PosteingangZeile`: oben der Empfänger, darunter der Betreff, darunter die
/// Chips, rechts nur die Uhrzeit (das Datum steht im Gruppenkopf).
///
/// Nicht `VersandEintragZeile` aus `email_versand`: Die verdichtet den Versand
/// zu **einem Satz** („Versendet am … an …"), weil sie in der Vorgangsliste in
/// einer einzigen Zeile neben anderen Angaben steht. Hier ist der Versand der
/// Gegenstand der Liste selbst und bekommt dieselbe dreizeilige Gestalt wie
/// eine eingegangene Nachricht — sonst läsen sich die beiden Bereiche
/// desselben Tabs wie zwei fremde Listen.
class GesendetZeile extends StatelessWidget {
  const GesendetZeile({super.key, required this.eintrag, this.zeichen});

  final VersandEintrag eintrag;

  /// Das Zeichen des Vorgangs („144/26 C03") für die Pille. Null, wenn der
  /// Vorgang zur Referenz nicht (mehr) im Bestand steht — dann steht die
  /// Referenz selbst da, statt die Zuordnung zu verschweigen.
  final String? zeichen;

  /// „Gesendet" nur, wo die App die Einlieferung wirklich gesehen hat
  /// (`VersandWeg.istNachweis`) — die Übergabe an Outlook ist kein Versand,
  /// und eine Pille, die das gleichsetzt, wäre als Nachweis schlechter als
  /// keine.
  String get _statustext => switch (eintrag.weg) {
    VersandWeg.direktversand => 'Gesendet',
    VersandWeg.outlookEntwurf => 'In Outlook geöffnet',
    VersandWeg.entwurfsdatei => 'Als Entwurfsdatei abgelegt',
  };

  String get _empfaenger {
    final alle = eintrag.alleEmpfaenger.where((e) => e.trim().isNotEmpty);
    return alle.isEmpty ? 'Ohne Empfänger' : alle.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _mitte(theme)),
          const SizedBox(width: 12),
          Text(
            deutscheUhrzeit(eintrag.gesendetAm),
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _mitte(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _empfaenger,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
      ),
      Text(
        eintrag.betreff.trim().isEmpty ? 'Ohne Betreff' : eintrag.betreff,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 4),
      // Wrap statt Row: Bei „Am größten" und schmaler Liste passen Pillen,
      // Büroklammer und Statuspille nicht mehr nebeneinander — umbrechen ist
      // richtig, überlaufen nicht.
      Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (_vorgangstext.isNotEmpty)
            StatusPille(text: _vorgangstext, farbe: theme.colorScheme.primary),
          if (eintrag.anhaenge.isNotEmpty) _bueroklammer(theme),
          StatusPille(
            text: _statustext,
            farbe: eintrag.weg.istNachweis
                ? theme.colorScheme.primary
                : theme.colorScheme.tertiary,
          ),
        ],
      ),
    ],
  );

  String get _vorgangstext {
    final aufgeloest = (zeichen ?? '').trim();
    return aufgeloest.isNotEmpty ? aufgeloest : eintrag.vorgangReferenz.trim();
  }

  Widget _bueroklammer(ThemeData theme) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.attach_file, size: 14, color: theme.colorScheme.outline),
      Text(
        '${eintrag.anhaenge.length}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    ],
  );
}
