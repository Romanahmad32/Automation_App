import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/zwischennachricht_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Badge sitzt in der Praxis im `subtitle` eines `ListTile` innerhalb der
/// auf 360 px festen Trefferspalte (`mailbox_reply_list.dart`) — dort bleibt
/// nach Leading-Icon und Innenabstand deutlich weniger als 360 px übrig. Der
/// `Row` im Badge hat `mainAxisSize: MainAxisSize.min` und kein Flex-Kind:
/// Bei "Am größten" (Issue #57) und dieser schmalen Spalte kann Icon + Text
/// breiter sein als der verfügbare Platz.
void main() {
  Future<void> zeigeBadgeInListTile(
    WidgetTester tester, {
    required double spaltenbreite,
  }) async {
    tester.view.physicalSize = const Size(600, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        // Das echte, auf „Am größten" angehobene Theme (Issue #57) — sonst
        // bliebe der Test blind für den gemeldeten Überlauf.
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: Schriftstufe.amGroessten,
        ).light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: spaltenbreite,
              child: const ListTile(
                leading: Icon(Icons.hourglass_top),
                title: Text(
                  '123/2026 K_HG-E 1427',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HUK-Coburg Versicherung AG · 05.09.2026 14:32',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: ZwischennachrichtBadge(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'das Zwischennachricht-Badge laeuft in der schmalen Trefferspalte bei '
    '"Am groessten" nicht ueber',
    (tester) async {
      await zeigeBadgeInListTile(tester, spaltenbreite: 360);

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Icon und Text im Badge stehen in einer Row mit '
            'mainAxisSize.min und ohne Flexible — bei "Am größten" und der '
            'schmalen Trefferspalte (360 px, abzüglich Leading-Icon und '
            'Innenabstand) lief das Badge über.',
      );
    },
  );
}
