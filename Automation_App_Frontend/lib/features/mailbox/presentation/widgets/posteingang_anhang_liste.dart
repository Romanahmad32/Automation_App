import 'package:automation_app/features/mailbox/domain/entities/posteingang_anhang.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_anhang_aktionen.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_anhang_zeile.dart';
import 'package:flutter/material.dart';

/// Das Anhangsverzeichnis der Detailansicht (Issue #134): Überschrift
/// „Anhänge" und darunter je Anhang eine [PosteingangAnhangZeile].
///
/// Die [aktionen] gelten für **jeden** Anhang gleichermaßen — die Handgriffe
/// (Öffnen, In die Akte, Beim Versand verwenden) unterscheiden sich nicht je
/// Zeile, nur ihr Ziel (der jeweilige [PosteingangAnhang]) tut es.
class PosteingangAnhangListe extends StatelessWidget {
  const PosteingangAnhangListe({
    super.key,
    required this.anhaenge,
    required this.aktionen,
  });

  final List<PosteingangAnhang> anhaenge;
  final PosteingangAnhangAktionen aktionen;

  @override
  Widget build(BuildContext context) {
    if (anhaenge.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Anhänge', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final anhang in anhaenge)
          PosteingangAnhangZeile(anhang: anhang, aktionen: aktionen),
      ],
    );
  }
}
