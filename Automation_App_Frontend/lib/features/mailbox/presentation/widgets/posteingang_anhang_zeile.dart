import 'package:automation_app/core/general_classes/dateigroesse_format.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_anhang_aktionen.dart';
import 'package:flutter/material.dart';

/// Eine Zeile im Anhangsverzeichnis der Detailansicht (Issue #134): Symbol
/// nach Medientyp, Dateiname, menschliche Größe und drei Handgriffe als
/// Symbolknöpfe (Öffnen, In die Akte, Beim Versand verwenden).
///
/// Läuft gerade ein Download für **diesen** Anhang
/// ([PosteingangAnhangAktionen.laeuft]), zeigt die Zeile einen schmalen
/// Fortschrittsring statt der drei Knöpfe: Ein Anhang-Download blockiert die
/// einzige Postfachverbindung für bis zu 45 s, und die Zeile darf in dieser
/// Zeit nicht so aussehen, als liesse sich ein zweiter Handgriff parallel
/// anstoßen.
class PosteingangAnhangZeile extends StatelessWidget {
  const PosteingangAnhangZeile({
    super.key,
    required this.anhang,
    required this.aktionen,
  });

  final PosteingangAnhang anhang;
  final PosteingangAnhangAktionen aktionen;

  /// Symbol nach grober Medienart — der genaue Subtyp (`png` gegen `jpeg`)
  /// spielt für die Wiedererkennung keine Rolle.
  static IconData symbolFuer(String medientyp) {
    final typ = medientyp.toLowerCase();
    if (typ.startsWith('image/')) return Icons.image_outlined;
    if (typ == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (typ.contains('word') || typ.contains('wordprocessing')) {
      return Icons.description_outlined;
    }
    if (typ.contains('excel') || typ.contains('spreadsheet')) {
      return Icons.table_chart_outlined;
    }
    if (typ.contains('zip') || typ.contains('compressed')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.attach_file;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            symbolFuer(anhang.medientyp),
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  anhang.dateiname,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                if (anhang.groesse > 0)
                  Text(
                    formatiereDateigroesse(anhang.groesse),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (aktionen.laeuft)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: 'Öffnen',
              visualDensity: VisualDensity.compact,
              onPressed: () => aktionen.onOeffnen(anhang),
            ),
            IconButton(
              icon: const Icon(Icons.folder_outlined, size: 18),
              tooltip: 'In die Akte',
              visualDensity: VisualDensity.compact,
              onPressed: () => aktionen.onInDieAkte(anhang),
            ),
            IconButton(
              icon: const Icon(Icons.outgoing_mail, size: 18),
              tooltip: 'Beim Versand verwenden',
              visualDensity: VisualDensity.compact,
              onPressed: () => aktionen.onBeimVersand(anhang),
            ),
          ],
        ],
      ),
    );
  }
}
