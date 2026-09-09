import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/views/posteingang_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'posteingang_cubit_test.dart';

void main() {
  for (final size in [const Size(1100, 700), const Size(480, 650)]) {
    testWidgets('Posteingang bei $size blättert ohne Überlauf', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = PosteingangTestRepository();
      final cubit = PosteingangCubit(repo, PosteingangTestPush());
      addTearDown(cubit.close);
      final laden = cubit.aktualisieren();
      repo.seiten.last.complete(
        PosteingangSeite(
          List.generate(
            50,
            (i) => PosteingangEintrag(
              id: '$i',
              betreff: 'Versicherung: Nachricht $i',
              absender:
                  'Versicherung mit einem langen Namen <versicherung@example.de>',
            ),
          ),
          'weiter',
          1000000,
        ),
      );
      await laden;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const PosteingangView(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('1000000 Nachrichten'), findsOneWidget);
      expect(repo.inhalte, isEmpty);
      await tester.tap(find.text('Ältere'));
      repo.seiten.last.complete(
        const PosteingangSeite(
          [
            PosteingangEintrag(
              id: 'alt',
              betreff: 'Ältere Nachricht',
              absender: 'Kanzlei',
            ),
          ],
          null,
          1000000,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ältere Nachricht'), findsOneWidget);
      expect(find.text('Versicherung: Nachricht 0'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
