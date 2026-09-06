import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/import_befund.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/utils/import_filter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Das Band über der Liste, wenn die Datei Ordner nennt, die es unter dem
/// Stammordner nicht gibt. Ein Klick darauf zeigt genau diese Zeilen.
///
/// Es steht **über** der Liste und nicht als Hinweis an den einzelnen Zeilen,
/// weil es die Antwort auf eine Frage ist, die sich sonst nicht stellt: Der
/// Übernehmen-Knopf ist grau, und ohne dieses Band bliebe unerklärlich, warum.
/// Deshalb sagt es beides — wie viele Zeilen betroffen sind und dass sie die
/// Übernahme aufhalten.
class ImportUnbekannteOrdnerBand extends StatelessWidget {
  final ImportBefund befund;

  /// Der laufende Filter — das Band schaltet ihn um und liest an ihm ab, ob es
  /// gerade selbst die Ansicht bestimmt.
  final ImportFilter filter;

  const ImportUnbekannteOrdnerBand({
    super.key,
    required this.befund,
    required this.filter,
  });

  bool get _aktiv => filter.sicht == ImportSicht.unbekannterOrdner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;
    final tone = SoftTone.fromAccent(farben.error, farben);

    return Material(
      color: tone.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _umschalten(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.folder_off_outlined, color: tone.foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zeilenText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tone.foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _erklaerung,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tone.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _aktiv ? 'Alle zeigen' : 'Zeilen zeigen',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: tone.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Der Wortlaut ist festgelegt, damit er überall gleich lautet; die
  /// Einzahlform steht daneben, weil „1 Zeilen nennen" nach einem Fehler in
  /// der App aussieht statt nach einem in der Datei.
  String get zeilenText {
    final anzahl = befund.unbekannteZeilen.length;
    if (anzahl == 0) {
      return 'Die Datei nennt Ordner, die es im Stammordner nicht gibt.';
    }
    if (anzahl == 1) {
      return 'Eine Zeile nennt einen Ordner, den es im Stammordner nicht gibt.';
    }
    return '$anzahl Zeilen nennen Ordner, die es im Stammordner nicht gibt.';
  }

  String get _erklaerung {
    final ohneBezug = befund.unbekannteOhneBezug.length;
    final dazu = ohneBezug == 0
        ? ''
        : ohneBezug == 1
        ? 'Dazu 1 Ordner unter „ohne Mandantenbezug". '
        : 'Dazu $ohneBezug Ordner unter „ohne Mandantenbezug". ';
    return '$dazuÜbernehmen bleibt gesperrt, bis keine unbekannte '
        'Ordnerangabe mehr in der Datei steht — berichtigen Sie die Zeile im '
        'Dialog oder lassen Sie sie weg.';
  }

  void _umschalten(BuildContext context) {
    final cubit = context.read<MandantenImportCubit>();
    cubit.filtern(
      filter.copyWith(
        sicht: _aktiv ? ImportSicht.alle : ImportSicht.unbekannterOrdner,
      ),
    );
  }
}
