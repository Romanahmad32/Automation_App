import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_datetime_format.dart';
import 'package:flutter/material.dart';

/// Kopf der Detailansicht (Issue #134): Betreff als Überschrift, darunter
/// „Von"/„An"/„Cc"/„Datum" in einer Beschriftungs- und einer Wertspalte.
///
/// Nimmt sowohl den Listeneintrag [eintrag] als auch den — erst nach dem
/// Öffnen vorliegenden — [inhalt] entgegen: Solange der Inhalt noch lädt oder
/// ein Fehler steht, zeigt der Kopf bereits Betreff und den rohen `absender`
/// aus der Zeile; sobald [inhalt] da ist, gewinnen dessen getrennt
/// ausgelesene Felder (Name/Adresse, An, Cc, Datum) — vollständiger als das,
/// was die Liste ohne Inhaltsabruf wissen kann.
class PosteingangDetailKopf extends StatelessWidget {
  const PosteingangDetailKopf({super.key, required this.eintrag, this.inhalt});

  final PosteingangEintrag eintrag;
  final PosteingangInhalt? inhalt;

  String get _von {
    final name = inhalt?.absenderName ?? eintrag.absenderName;
    final adresse = inhalt?.absenderAdresse ?? eintrag.absenderAdresse;
    final hatName = (name ?? '').trim().isNotEmpty;
    final hatAdresse = (adresse ?? '').trim().isNotEmpty;
    if (hatName && hatAdresse) return '$name <$adresse>';
    if (hatName) return name!;
    if (hatAdresse) return adresse!;
    return eintrag.absender;
  }

  List<String> get _an => inhalt?.an ?? const [];
  List<String> get _cc => inhalt?.cc ?? const [];
  DateTime? get _datum => inhalt?.datum ?? eintrag.datum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final datum = _datum;
    final zeilen = <(String, String)>[
      ('Von', _von),
      if (_an.isNotEmpty) ('An', _an.join(', ')),
      if (_cc.isNotEmpty) ('Cc', _cc.join(', ')),
      if (datum != null) ('Datum', formatMailboxDateTime(datum)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(eintrag.betreff, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final zeile in zeilen)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    '${zeile.$1}:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    zeile.$2,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
