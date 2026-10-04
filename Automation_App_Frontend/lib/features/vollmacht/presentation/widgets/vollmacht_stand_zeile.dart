import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';

/// Die Zeile in der Vorgangskachel, die sagt, ob die Vollmacht gedruckt ist
/// (§4.11) — im Stil des Hinweises auf fehlende Daten darunter.
///
/// Dazu der Schalter für Fälle, in denen die Vollmacht anders zustande kam
/// (von Hand ausgefüllt, vom Mandanten mitgebracht) oder der Vermerk falsch
/// ist. Ein erneuter Druck setzt das Datum ohnehin neu.
class VollmachtStandZeile extends StatefulWidget {
  final Vorgang vorgang;

  const VollmachtStandZeile({super.key, required this.vorgang});

  @override
  State<VollmachtStandZeile> createState() => VollmachtStandZeileState();
}

class VollmachtStandZeileState extends State<VollmachtStandZeile> {
  bool _arbeitet = false;

  Future<void> _schalte({required bool gedruckt}) async {
    final rueckmeldung = Rueckmeldung.von(context);
    setState(() => _arbeitet = true);
    final ok = await getIt<VorgangCubit>().vermerkeVollmacht(
      widget.vorgang.referenz,
      gedruckt: gedruckt,
    );
    if (!mounted) return;
    setState(() => _arbeitet = false);
    if (!ok) {
      rueckmeldung.fehler(
        'Der Vollmacht-Vermerk konnte nicht gespeichert werden. '
        'Bitte erneut versuchen.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gedrucktAm = widget.vorgang.vollmachtGedrucktAm;
    final farbe = gedrucktAm == null
        ? theme.colorScheme.tertiary
        : theme.colorScheme.outline;
    final stil = theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Icon(
            gedrucktAm == null ? Icons.draw_outlined : Icons.task_alt,
            size: 16,
            color: farbe,
          ),
          Text(
            gedrucktAm == null
                ? 'Vollmacht noch nicht gedruckt'
                : 'Vollmacht gedruckt am ${deutschesDatum(gedrucktAm)}',
            style: stil?.copyWith(color: farbe),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              textStyle: stil,
            ),
            onPressed: _arbeitet
                ? null
                : () => _schalte(gedruckt: gedrucktAm == null),
            child: Text(
              gedrucktAm == null
                  ? 'als gedruckt vermerken'
                  : 'Vermerk zurücknehmen',
            ),
          ),
        ],
      ),
    );
  }
}
