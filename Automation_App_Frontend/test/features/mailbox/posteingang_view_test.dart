import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/gesendet_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_bereiche.dart';
import 'package:automation_app/features/mailbox/presentation/views/posteingang_view.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_detail.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_zeile.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_zentralruf_detail.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mailbox_doubles.dart';
import 'posteingang_cubit_test.dart';

/// Der Posteingang als **ein** bedienbarer Bereich (Variante B zu Issue #134):
/// Eine Zeile, zu der schon eine Zentralruf-Antwort erfasst ist, öffnet deren
/// Formular statt des Mailtexts; der Filter grenzt die Liste ein; der
/// Vorgangsbezug entsteht ohne Zutun aus dem Betreff; und der Umschalter
/// darüber führt zum Bereich „Gesendet".
void main() {
  const zentralrufSchluessel = 'zr-2026-09-13@gdv.de';

  final vorgang = Vorgang(
    referenz: '144/2026 K_HG-E 1427',
    angefragtAm: DateTime(2026, 9, 1),
    laufendeNummer: 144,
    jahr: '2026',
    abteilung: 'C03',
  );

  PosteingangEintrag mail(
    String id, {
    required String betreff,
    String? messageId,
  }) => PosteingangEintrag(
    id: id,
    betreff: betreff,
    absender: 'Zentralruf <zentralruf@gdv.de>',
    absenderName: 'Zentralruf der Autoversicherer',
    absenderAdresse: 'zentralruf@gdv.de',
    messageId: messageId,
    datum: DateTime(2026, 9, 13, 9, 30),
  );

  ReceivedReply antwort() => ReceivedReply(
    id: 'antwort-1',
    receivedAt: DateTime(2026, 9, 13, 9, 31),
    subject: 'Auskunft zu Ihrer Anfrage',
    from: 'zentralruf@gdv.de',
    acknowledged: false,
    warnings: const [],
    data: const ZentralrufReplyData(
      referenz: '144/2026 K_HG-E 1427',
      versichererName: 'HUK-COBURG',
    ),
    mailSchluessel: '<$zentralrufSchluessel>',
  );

  tearDown(() => getIt.reset());

  /// Die Attrappe des laufenden Tests — der Mailtext kommt erst, wenn der Test
  /// ihn liefert (`PosteingangTestRepository` arbeitet mit `Completer`).
  late PosteingangTestRepository repo;

  /// Öffnet eine Zeile und liefert ihren Text nach, damit die Ansicht zur Ruhe
  /// kommt: Ohne Inhalt dreht sich der Ladebalken des Details endlos, und
  /// `pumpAndSettle` läuft in seine Zeitgrenze.
  Future<void> oeffne(WidgetTester tester, String id) async {
    await tester.tap(find.byType(PosteingangZeile).first);
    await tester.pump();
    repo.inhalte[id]?.complete(
      const PosteingangInhalt(text: 'Sehr geehrte Damen und Herren, …'),
    );
    await tester.pumpAndSettle();
  }

  /// Baut die Ansicht mit einer bereits geladenen Seite auf.
  Future<PosteingangCubit> zeige(
    WidgetTester tester, {
    required List<PosteingangEintrag> eintraege,
    List<ReceivedReply> antworten = const [],
    List<Vorgang> vorgaenge = const [],
    Size groesse = const Size(1400, 900),
  }) async {
    registriereMailboxBestaende(vorgaenge: vorgaenge);
    tester.view.physicalSize = groesse;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    repo = PosteingangTestRepository();
    final cubit = PosteingangCubit(repo, PosteingangTestPush());
    addTearDown(cubit.close);
    final laden = cubit.aktualisieren();
    repo.seiten.last.complete(
      PosteingangSeite(eintraege, null, eintraege.length),
    );
    await laden;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider(
                create: (_) => MailboxInboxCubit(
                  MailboxTestAntworten(antworten),
                  PosteingangTestPush(),
                )..refresh(),
              ),
            ],
            child: const PosteingangView(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Der Rückfall-Timer der Ansicht liefe sonst über das Testende hinaus.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    return cubit;
  }

  testWidgets(
    'eine erfasste Zentralruf-Antwort oeffnet ihr Formular, "Mail anzeigen" '
    'schaltet auf den Mailtext um',
    (tester) async {
      await zeige(
        tester,
        eintraege: [
          mail(
            'a',
            betreff: 'Auskunft zu Ihrer Anfrage',
            messageId: zentralrufSchluessel,
          ),
        ],
        antworten: [antwort()],
      );

      await oeffne(tester, 'a');

      expect(find.byType(PosteingangZentralrufDetail), findsOneWidget);
      expect(find.byType(PosteingangDetail), findsNothing);
      // Die Zeile selbst trägt die Markierung, damit sie in der Liste
      // auffindbar bleibt.
      expect(find.text('Zentralruf · offen'), findsWidgets);

      await tester.tap(find.text('Mail anzeigen'));
      await tester.pumpAndSettle();

      expect(find.byType(PosteingangDetail), findsOneWidget);
      expect(find.byType(PosteingangZentralrufDetail), findsNothing);
    },
  );

  testWidgets('eine Zeile ohne erfasste Antwort zeigt den Mailtext', (
    tester,
  ) async {
    await zeige(
      tester,
      eintraege: [mail('a', betreff: 'Rechnung', messageId: 'anderes@x.de')],
      antworten: [antwort()],
    );

    await oeffne(tester, 'a');

    expect(find.byType(PosteingangDetail), findsOneWidget);
    expect(find.byType(PosteingangZentralrufDetail), findsNothing);
  });

  testWidgets(
    'der Filter "Zentralruf" laesst nur die erfassten Zeilen stehen',
    (tester) async {
      await zeige(
        tester,
        eintraege: [
          mail(
            'a',
            betreff: 'Auskunft zu Ihrer Anfrage',
            messageId: zentralrufSchluessel,
          ),
          mail('b', betreff: 'Rechnung der Werkstatt', messageId: 'werk@x.de'),
        ],
        antworten: [antwort()],
      );

      expect(find.byType(PosteingangZeile), findsNWidgets(2));

      // Die Filterleiste steht genau einmal auf dem Bildschirm — über der
      // Liste, nicht zusätzlich in der Werkzeugleiste (Review zu #134).
      expect(find.text('Zentralruf (1)'), findsOneWidget);
      await tester.tap(find.text('Zentralruf (1)'));
      await tester.pumpAndSettle();

      expect(find.byType(PosteingangZeile), findsOneWidget);
      expect(find.text('Auskunft zu Ihrer Anfrage'), findsOneWidget);
      expect(find.text('Rechnung der Werkstatt'), findsNothing);
    },
  );

  testWidgets(
    'das Zeichen im Betreff wird ohne Zutun zum Vorgangsbezug der Zeile',
    (tester) async {
      await zeige(
        tester,
        eintraege: [
          mail('a', betreff: 'Ihr Zeichen 144/2026 C03 — Schadenmeldung'),
        ],
        vorgaenge: [vorgang],
      );

      // Der Erkenner läuft nach jeder Seitenladung und nach jeder Änderung am
      // Vorgangsbestand — der Cubit lädt seine Vorgänge asynchron nach.
      await tester.pumpAndSettle();

      expect(find.text('144/2026 C03'), findsOneWidget);
    },
  );

  testWidgets('ohne passenden Vorgang bleibt die Zeile ohne Pille', (
    tester,
  ) async {
    await zeige(
      tester,
      eintraege: [mail('a', betreff: 'Newsletter')],
      vorgaenge: [vorgang],
    );
    await tester.pumpAndSettle();

    expect(find.text('144/2026 C03'), findsNothing);
  });

  testWidgets(
    'schmal liegt die geoeffnete Mail als Vollbild ueber der Liste, mit '
    'Zurueck-Pfeil',
    (tester) async {
      final cubit = await zeige(
        tester,
        eintraege: [mail('a', betreff: 'Rechnung der Werkstatt')],
        groesse: const Size(900, 800),
      );

      await oeffne(tester, 'a');

      expect(find.byType(PosteingangZeile), findsNothing);
      expect(find.byType(PosteingangDetail), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(cubit.state.auswahl, isNull);
      expect(find.byType(PosteingangZeile), findsOneWidget);
    },
  );

  testWidgets('der Umschalter fuehrt vom Posteingang zu "Gesendet"', (
    tester,
  ) async {
    registriereMailboxBestaende();
    getIt.registerFactory<PosteingangCubit>(
      () =>
          PosteingangCubit(PosteingangTestRepository(), PosteingangTestPush()),
    );
    getIt.registerFactory<GesendetCubit>(
      () => GesendetCubit(VersandTestProtokoll()),
    );
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider(
            create: (_) =>
                MailboxInboxCubit(MailboxTestAntworten(), PosteingangTestPush())
                  ..refresh(),
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

    expect(find.byType(PosteingangView), findsNothing);
    expect(find.text('Noch nichts aus der App versendet.'), findsOneWidget);
  });
}
