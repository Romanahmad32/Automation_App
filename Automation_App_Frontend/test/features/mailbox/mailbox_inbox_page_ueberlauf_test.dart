import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/gesendet_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/pages/mailbox_inbox_page.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_status_pille.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_zeile.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mailbox_doubles.dart';
import 'posteingang_cubit_test.dart';

/// Nachfolger des Überlauf-Tests zu `mailbox_inbox_view.dart` (Issue #57): Die
/// dort geprüfte Spaltenaufteilung gibt es nicht mehr — seit Issue #134 stehen
/// Werkzeugleiste, Liste und Detail im Posteingang. Geprüft wird dasselbe
/// Risiko an der neuen Stelle: Bei „Am größten" und einem schmalen Fenster
/// (900 px, also unterhalb der 1080 px, ab denen Liste und Detail
/// nebeneinanderstehen) darf nichts überlaufen — weder die Werkzeugleiste mit
/// Filterchips und drei Knöpfen noch die Kopfzeile mit der Statuspille.
void main() {
  final eintraege = [
    for (var i = 0; i < 4; i++)
      PosteingangEintrag(
        id: '$i',
        betreff: 'Anspruchsschreiben zum Unfall vom 12.05.2026 — Nachfrage $i',
        absender:
            'Versicherung mit einem sehr langen Namen '
            '<schaden@versicherung-mit-langem-namen.de>',
        absenderName: 'Versicherung mit einem sehr langen Namen',
        absenderAdresse: 'schaden@versicherung-mit-langem-namen.de',
        datum: DateTime(2026, 9, 13, 9, 30),
        anzahlAnhaenge: 2,
        hatAnhaenge: true,
      ),
  ];

  tearDown(() => getIt.reset());

  Future<void> zeigeSeite(WidgetTester tester, {required double breite}) async {
    registriereMailboxBestaende();
    final repo = PosteingangTestRepository();
    getIt.registerFactory<PosteingangCubit>(
      () => PosteingangCubit(repo, PosteingangTestPush()),
    );
    getIt.registerFactory<GesendetCubit>(
      () => GesendetCubit(VersandTestProtokoll()),
    );

    tester.view.physicalSize = Size(breite, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ZentralrufReplyBloc(NieAufgerufenesAuswerten()),
          ),
          BlocProvider(
            create: (_) =>
                MailboxInboxCubit(MailboxTestAntworten(), PosteingangTestPush())
                  ..refresh(),
          ),
        ],
        child: MaterialApp(
          // Das echte, auf „Am größten" angehobene Theme (Issue #57) — sonst
          // bliebe der Test blind für den gemeldeten Überlauf.
          theme: MaterialTheme(
            ThemeData.light().textTheme,
            schriftstufe: Schriftstufe.amGroessten,
          ).light(),
          home: const MailboxInboxPage(),
        ),
      ),
    );
    // Kein pumpAndSettle: Solange die erste Seite aussteht, dreht sich der
    // Ladebalken der Liste endlos.
    await tester.pump();
    repo.seiten.last.complete(
      PosteingangSeite(eintraege, null, eintraege.length),
    );
    await tester.pump();
    await tester.pump();
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  for (final breite in [900.0, 1400.0]) {
    testWidgets(
      'die Postfach-Seite laeuft bei "Am groessten" und ${breite}px nicht '
      'ueber',
      (tester) async {
        await zeigeSeite(tester, breite: breite);

        expect(find.byType(MailboxStatusPille), findsOneWidget);
        expect(find.byType(PosteingangZeile), findsWidgets);
        expect(
          tester.takeException(),
          isNull,
          reason:
              'Werkzeugleiste (vier Filterchips, Neu laden, „Antwort manuell '
              'einfügen", „Neue E-Mail") und Kopfzeile mit Statuspille müssen '
              'bei „Am größten" umbrechen statt überzulaufen.',
        );
      },
    );
  }

  testWidgets(
    'auch die geoeffnete Mail als Vollbild laeuft bei 900px nicht ueber',
    (tester) async {
      await zeigeSeite(tester, breite: 900);

      await tester.tap(find.byType(PosteingangZeile).first);
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
