import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/gesendet_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_bereiche.dart';
import 'package:automation_app/features/mailbox/presentation/views/posteingang_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mailbox_doubles.dart';
import 'posteingang_cubit_test.dart';

/// Deckt die Entscheidung des Masters zu Issue #134, Befund 4 ab:
/// `PosteingangCubit` lebt jetzt als `@lazySingleton` für die Sitzung (statt
/// als `@injectable`-Factory), und `MailboxBereiche` bindet ihn über
/// `BlocProvider.value` ein — sonst schlösse ein gewöhnlicher
/// `BlocProvider(create: …)` den Cubit beim Wechsel zu „Gesendet", obwohl er
/// für die ganze Sitzung leben soll.
void main() {
  tearDown(() => getIt.reset());

  testWidgets(
    'ein Wechsel zu "Gesendet" und zurück schließt den Posteingang-Cubit '
    'nicht und behält "Nicht zuordnen"',
    (tester) async {
      registriereMailboxBestaende();
      final repo = PosteingangTestRepository();
      final cubit = PosteingangCubit(repo, PosteingangTestPush());
      addTearDown(cubit.close);
      getIt.registerLazySingleton<PosteingangCubit>(() => cubit);
      getIt.registerLazySingleton<GesendetCubit>(
        () => GesendetCubit(VersandTestProtokoll()),
      );
      final laden = cubit.aktualisieren();
      repo.seiten.last.complete(
        const PosteingangSeite(
          [PosteingangEintrag(id: 'a', betreff: 'A', absender: 'A')],
          null,
          1,
        ),
      );
      await laden;
      cubit.nichtZuordnen('a');

      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider(
              create: (_) => MailboxInboxCubit(
                MailboxTestAntworten(),
                PosteingangTestPush(),
              )..refresh(),
              child: const MailboxBereiche(),
            ),
          ),
        ),
      );
      await tester.pump();
      addTearDown(() => tester.pumpWidget(const SizedBox()));
      expect(find.byType(PosteingangView), findsOneWidget);

      await tester.tap(find.text('Gesendet'));
      await tester.pumpAndSettle();

      expect(
        cubit.isClosed,
        isFalse,
        reason:
            'BlocProvider.value darf den geteilten Cubit beim Verlassen '
            'nicht schließen',
      );

      await tester.tap(find.text('Posteingang'));
      await tester.pumpAndSettle();

      expect(find.byType(PosteingangView), findsOneWidget);
      expect(cubit.state.nichtZuordnen, contains('a'));
      expect(identical(cubit, getIt<PosteingangCubit>()), isTrue);
    },
  );
}
