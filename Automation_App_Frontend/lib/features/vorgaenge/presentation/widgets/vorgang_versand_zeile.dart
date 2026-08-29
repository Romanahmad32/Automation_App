import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/letzte_versaende_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/utils/versand_darstellung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/versand_protokoll_dialog.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/versand_weg_symbol.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sagt in der Vorgangsliste, ob und wann zu diesem Vorgang etwas hinausging
/// (§4.7) — anklickbar für die ganze Reihe.
///
/// Für eine Kanzlei ist „ist das Anspruchsschreiben raus?" die Frage, die man
/// an einer Vorgangsliste stellt. Sie war bisher nur im Postfach zu
/// beantworten: Der Versandstand lebte nur, solange der Dialog offen war.
///
/// Steht nichts da, heißt das **nicht** „nicht versendet", sondern „die App
/// hat nichts versendet" — was außerhalb hinausging, weiß sie nicht. Deshalb
/// bleibt die Zeile leer statt zu behaupten, es sei nichts geschehen.
class VorgangVersandZeile extends StatefulWidget {
  final String referenz;

  const VorgangVersandZeile({super.key, required this.referenz});

  @override
  State<VorgangVersandZeile> createState() => _VorgangVersandZeileState();
}

class _VorgangVersandZeileState extends State<VorgangVersandZeile> {
  @override
  void initState() {
    super.initState();
    // Die erste Zeile der Liste löst den einen Abruf aus, die übrigen finden
    // den Stand vor.
    getIt<LetzteVersaendeCubit>().ladenWennNoetig();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<LetzteVersaendeCubit, Map<String, VersandEintrag>>(
      bloc: getIt<LetzteVersaendeCubit>(),
      builder: (context, stand) {
        final eintrag = getIt<LetzteVersaendeCubit>().zu(widget.referenz);
        if (eintrag == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: InkWell(
            onTap: () =>
                VersandProtokollDialog.zeigen(context, widget.referenz),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                VersandWegSymbol(weg: eintrag.weg, groesse: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    VersandDarstellung.kurz(eintrag),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
