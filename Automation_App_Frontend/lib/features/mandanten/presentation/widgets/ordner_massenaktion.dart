import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart';
import 'package:automation_app/features/mandanten/presentation/utils/zuordnung_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// „Alle gerade gefilterten entscheiden" — ohne diese Aktion ist der Rest eines
/// Bestands von rund 4000 Ordnern auch nach allen Filtern nicht zu schaffen.
///
/// Sie wirkt genau auf das, was gerade in der Liste steht: erst filtern, dann
/// sehen, dann entscheiden. Weil sie viele Zeilen auf einmal umlegt, fragt sie
/// vorher nach — und weil ein Vermerk kein Löschen ist, sagt die Rückfrage das
/// auch.
class OrdnerMassenaktion extends StatelessWidget {
  /// Die gerade sichtbaren Ordner — nur sie sind betroffen.
  final List<Akte> sichtbar;

  /// Welcher Topf gezeigt wird; er bestimmt die Richtung der Aktion.
  final OrdnerAnsicht ansicht;

  const OrdnerMassenaktion({
    super.key,
    required this.sichtbar,
    required this.ansicht,
  });

  bool get _nimmtZurueck => ansicht == OrdnerAnsicht.ohneBezug;

  String get _beschriftung => _nimmtZurueck
      ? 'Alle ${sichtbar.length} zurück in den Stapel'
      : 'Alle ${sichtbar.length} als „ohne Mandantenbezug" markieren';

  @override
  Widget build(BuildContext context) {
    if (sichtbar.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _fragen(context),
        icon: Icon(_nimmtZurueck ? Icons.undo : Icons.block_outlined, size: 18),
        label: Text(_beschriftung),
      ),
    );
  }

  Future<void> _fragen(BuildContext context) async {
    final bloc = context.read<MandantenOverviewBloc>();
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _nimmtZurueck ? 'Zurück in den Stapel' : 'Ohne Mandantenbezug',
        ),
        content: Text(
          _nimmtZurueck
              ? '${sichtbar.length} Ordner stehen danach wieder als offen im '
                    'Zuordnungsstapel.'
              : '${sichtbar.length} Ordner werden als „ohne Mandantenbezug" '
                    'vermerkt. Es wird nichts gelöscht und kein Ordner '
                    'angefasst — der Vermerk ist jederzeit zurücknehmbar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_nimmtZurueck ? 'Zurücknehmen' : 'Markieren'),
          ),
        ],
      ),
    );
    if (bestaetigt != true) return;

    bloc.add(
      SetzeOrdnerStatusEvent(
        ordnernamen: [for (final akte in sichtbar) akte.ordnername],
        art: _nimmtZurueck ? null : OrdnerStatusArt.ohneMandantenbezug,
      ),
    );
  }
}
