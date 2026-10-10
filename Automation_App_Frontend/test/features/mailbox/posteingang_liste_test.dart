import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/vorgangsbezug.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_filter.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_state.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_gruppen_kopf.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_liste.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_zeilen_chips.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'posteingang_cubit_test.dart';

Vorgang _vorgang() => Vorgang.ausAnfrage(
  referenz: '144/26 C03_HG-E 1427',
  angefragtAm: DateTime(2026, 9, 1),
);

Future<void> _zeige(
  WidgetTester tester,
  PosteingangState state, {
  double breite = 1100,
  Schriftstufe schriftstufe = Schriftstufe.normal,
}) async {
  tester.view.physicalSize = Size(breite, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    BlocProvider(
      create: (_) =>
          PosteingangCubit(PosteingangTestRepository(), PosteingangTestPush()),
      child: MaterialApp(
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: schriftstufe,
        ).light(),
        home: Scaffold(body: PosteingangListe(state: state)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final heute = DateTime.now();
  final heuteTag = DateTime(heute.year, heute.month, heute.day, 9, 30);
  final gestern = heuteTag.subtract(const Duration(days: 1));

  final ungelesen = PosteingangEintrag(
    id: '1',
    betreff: 'Anfrage zum Vorgang',
    absender: 'Max Muster <max@x.de>',
    absenderName: 'Max Muster',
    datum: heuteTag,
    gelesen: false,
    messageId: 'Msg-1',
    hatAnhaenge: true,
    anzahlAnhaenge: 2,
  );
  final gelesen = PosteingangEintrag(
    id: '2',
    betreff: 'Rückfrage',
    absender: 'HUK <huk@x.de>',
    datum: gestern,
    gelesen: true,
  );

  testWidgets('gruppiert die Zeilen nach Tag mit einem Gruppenkopf je Tag', (
    tester,
  ) async {
    final state = PosteingangState(
      eintraege: [ungelesen, gelesen],
      seite: const PosteingangSeite([], null, 2),
    );
    await _zeige(tester, state);

    expect(find.byType(PosteingangGruppenKopf), findsNWidgets(2));
    expect(find.textContaining('HEUTE'), findsOneWidget);
    expect(find.textContaining('GESTERN'), findsOneWidget);
  });

  testWidgets('ungelesene Zeile zeigt den Absender fett', (tester) async {
    final state = PosteingangState(
      eintraege: [ungelesen],
      seite: const PosteingangSeite([], null, 1),
    );
    await _zeige(tester, state);

    final text = tester.widget<Text>(find.text('Max Muster'));
    expect(text.style?.fontWeight, FontWeight.bold);
  });

  testWidgets('gelesene Zeile zeigt den Absender nicht fett', (tester) async {
    final state = PosteingangState(
      eintraege: [gelesen],
      seite: const PosteingangSeite([], null, 1),
    );
    await _zeige(tester, state);

    final text = tester.widget<Text>(find.text('HUK <huk@x.de>'));
    expect(text.style?.fontWeight, isNot(FontWeight.bold));
  });

  testWidgets('zeigt Vorgangs-, Zentralruf- und Anhang-Chip einer Zeile', (
    tester,
  ) async {
    final bezug = Vorgangsbezug(
      vorgang: _vorgang(),
      sicherheit: BezugSicherheit.sicher,
      grund: 'Zeichen 144/26 C03 steht im Betreff',
    );
    final state = PosteingangState(
      eintraege: [ungelesen],
      seite: const PosteingangSeite([], null, 1),
      bezuege: {'1': bezug},
      zentralrufSchluessel: const {'msg-1'},
      zentralrufOffen: const {'msg-1'},
    );
    await _zeige(tester, state);

    expect(find.byType(PosteingangZeilenChips), findsOneWidget);
    expect(find.text('144/26 C03'), findsOneWidget);
    expect(find.text('Zentralruf · offen'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PosteingangZeilenChips),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Fußzeile zeigt am Deckel den Hinweis aufs Mailprogramm statt "Ältere laden"',
    (tester) async {
      final viele = List.generate(
        PosteingangState.deckel,
        (i) => PosteingangEintrag(
          id: 'e$i',
          betreff: 'B$i',
          absender: 'A',
          datum: heuteTag,
        ),
      );
      final state = PosteingangState(
        eintraege: viele,
        seite: const PosteingangSeite([], 'weiter', 900),
      );
      await _zeige(tester, state);

      expect(find.textContaining('im Mailprogramm'), findsOneWidget);
      expect(find.textContaining('Ältere laden'), findsNothing);
    },
  );

  testWidgets(
    'Fußzeile bietet "Ältere laden" an, solange nicht alles geladen',
    (tester) async {
      final state = PosteingangState(
        eintraege: [ungelesen],
        seite: const PosteingangSeite([], 'weiter', 5),
      );
      await _zeige(tester, state);

      expect(find.textContaining('Ältere laden'), findsOneWidget);
    },
  );

  testWidgets('Filterchip wechselt den Filter im Cubit', (tester) async {
    final state = PosteingangState(
      eintraege: [ungelesen, gelesen],
      seite: const PosteingangSeite([], null, 2),
    );
    late PosteingangCubit cubit;
    await tester.pumpWidget(
      BlocProvider(
        create: (_) {
          cubit = PosteingangCubit(
            PosteingangTestRepository(),
            PosteingangTestPush(),
          );
          return cubit;
        },
        child: MaterialApp(
          home: Scaffold(body: PosteingangListe(state: state)),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Mit Vorgang'));
    await tester.pump();

    expect(cubit.state.filter, PosteingangFilter.mitVorgang);
  });

  for (final breite in [1100.0, 360.0]) {
    testWidgets('läuft bei "Am größten" und ${breite}px nicht über', (
      tester,
    ) async {
      final state = PosteingangState(
        eintraege: [ungelesen, gelesen],
        seite: const PosteingangSeite([], 'weiter', 800),
        bezuege: {
          '1': Vorgangsbezug(
            vorgang: _vorgang(),
            sicherheit: BezugSicherheit.vermutet,
            grund: 'Absender ist der Mandant Max Muster',
          ),
        },
        zentralrufSchluessel: const {'msg-1'},
        zentralrufOffen: const {'msg-1'},
      );
      await _zeige(
        tester,
        state,
        breite: breite,
        schriftstufe: Schriftstufe.amGroessten,
      );

      expect(tester.takeException(), isNull);
    });
  }
}
