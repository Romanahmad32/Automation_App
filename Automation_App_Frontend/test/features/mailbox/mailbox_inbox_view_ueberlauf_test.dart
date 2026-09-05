import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_push_notifier.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_repository.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_auswahl_signal.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_inbox_view.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wird in diesem Test nie aufgerufen — es geht nur um das Layout, nicht ums
/// Auswerten selbst.
class _NieAufgerufenesAuswerten
    implements UseCase<ZentralrufReplyParseResult, ZentralrufReplyInput> {
  @override
  Future<Either<Failure, ZentralrufReplyParseResult>> call(
    ZentralrufReplyInput params,
  ) => throw UnimplementedError();
}

/// Liefert einen festen Status und die im Konstruktor übergebenen Treffer —
/// mehr braucht das Layout der Ansicht nicht.
class _FesteMailboxAntworten implements MailboxRepository {
  final List<ReceivedReply> replies;
  _FesteMailboxAntworten(this.replies);

  @override
  Future<Either<Failure, MailboxConfig>> getConfig() async =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, MailboxConfig>> saveConfig(
    MailboxConfigUpdate update,
  ) async => throw UnimplementedError();
  @override
  Future<Either<Failure, MailboxConfig>> microsoftSignIn() async =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, MailboxConfig>> microsoftSignOut() async =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, MailboxStatus>> getStatus() async => Right(
    const MailboxStatus(
      enabled: true,
      configured: true,
      connected: true,
      idleSupported: true,
      lastConnectedAt: null,
      lastReplyAt: null,
      lastError: null,
      receivedCount: 0,
      pendingCount: 0,
    ),
  );
  @override
  Future<Either<Failure, List<ReceivedReply>>> getReplies({
    bool includeAcknowledged = false,
  }) async => Right(replies);
  @override
  Future<Either<Failure, void>> acknowledge(String id) async => Right(null);
}

/// Feuert nie — der Hub selbst ist hier nicht Gegenstand des Tests.
class _StummerPushNotifier implements MailboxPushNotifier {
  @override
  Stream<void> get onReplyReceived => const Stream.empty();
  @override
  Stream<void> get onStatusChanged => const Stream.empty();
  @override
  Future<void> ensureConnected() async {}
  @override
  Future<void> dispose() async {}
}

/// `MailboxVersandLeiste` fragt bei gewähltem Treffer `getIt<VorgangCubit>()`
/// — hier bleibt der Bestand leer, es geht nur ums Layout.
class _LeereVorgangAblage implements VorgangRepository {
  @override
  Future<Vorgang?> setzeEntwurf(String referenz, VorgangEntwurf? entwurf) =>
      throw UnimplementedError();
  @override
  Future<List<Vorgang>> loadVorgaenge() async => [];
  @override
  Future<Vorgang> upsertVorgang(Vorgang vorgang) => throw UnimplementedError();
  @override
  Future<void> deleteVorgang(String referenz) => throw UnimplementedError();
  @override
  Future<Vorgang?> abschliessenVorgang(String referenz) async => null;
  @override
  Future<Vorgang?> aendereReferenz(String von, String nach) async => null;
}

List<ReceivedReply> _dreiEintraege() => [
  ReceivedReply(
    id: '1',
    receivedAt: DateTime(2026, 9, 5, 14, 32),
    subject: 'Auskunft zu Ihrer Anfrage',
    from: 'zentralruf@gdv-dienstleistungs-gmbh.de',
    acknowledged: false,
    warnings: const ['Kennzeichen passt nicht zur Referenz'],
    data: const ZentralrufReplyData(
      referenz: '123/2026 K_HG-E 1427',
      versichererName: 'HUK-Coburg Allgemeine Versicherung AG',
    ),
  ),
  ReceivedReply(
    id: '2',
    receivedAt: DateTime(2026, 9, 4, 9, 15),
    subject: 'Zwischennachricht',
    from: 'zentralruf@gdv-dienstleistungs-gmbh.de',
    acknowledged: false,
    warnings: const [],
    data: const ZentralrufReplyData(
      referenz: '124/2026 K_M-AB 2026',
      versichererName: 'Allianz Versicherungs-Aktiengesellschaft',
      zwischennachricht: true,
    ),
  ),
  ReceivedReply(
    id: '3',
    receivedAt: DateTime(2026, 9, 3, 8, 0),
    subject: 'Negativauskunft',
    from: 'zentralruf@gdv-dienstleistungs-gmbh.de',
    acknowledged: false,
    warnings: const [],
    data: const ZentralrufReplyData(keinVersichererErmittelt: true),
  ),
];

/// Die rechte Spalte „Antwortmail des Zentralrufs" (manueller Weg) stand in
/// `mailbox_inbox_view.dart` hinter einer fest verdrahteten 360-px-Liste in
/// einer nicht scrollbaren `Column` — bei „Am größten" (Issue #57) und einem
/// schmalen Fenster brachen Titel und Erklärtext in viele Zeilen, und die
/// Spalte lief unten über.
void main() {
  setUp(() {
    getIt.registerSingleton<MailboxAuswahlSignal>(MailboxAuswahlSignal());
    getIt.registerSingleton<VorgangCubit>(
      VorgangCubit(_LeereVorgangAblage(), VorgangPersistenzFehlerCubit()),
    );
  });

  tearDown(() => getIt.reset());

  Future<void> zeigeMitManuellerEingabe(
    WidgetTester tester, {
    required List<ReceivedReply> replies,
    required double breite,
  }) async {
    tester.view.physicalSize = Size(breite, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => MailboxInboxCubit(
              _FesteMailboxAntworten(replies),
              _StummerPushNotifier(),
            )..refresh(),
          ),
          BlocProvider(
            create: (_) => ZentralrufReplyBloc(_NieAufgerufenesAuswerten()),
          ),
        ],
        child: MaterialApp(
          // Das echte, auf „Am größten" angehobene Theme (Issue #57) — sonst
          // bliebe der Test blind für den gemeldeten Überlauf.
          theme: MaterialTheme(
            ThemeData.light().textTheme,
            schriftstufe: Schriftstufe.amGroessten,
          ).light(),
          home: const Scaffold(body: MailboxInboxView()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    // "Manuell einfügen" öffnet das Panel mit Titel, Erklärtext und Knöpfen —
    // genau die Spalte aus dem Screenshot-Befund.
    await tester.tap(find.text('Manuell einfügen'));
    await tester.pump();
  }

  // 1050 px Inhaltsbreite: die im Issue genannte Fenstergröße (Sidebar
  // ausgeklappt, ~1300 px Fenster). 750 px steht für ein weiter verengtes
  // Fenster — erst dort unterschreitet die Restbreite des Panels in dieser
  // Nachbildung tatsächlich das Maß, an dem Titel/Erklärtext in genug Zeilen
  // umbrechen, um die alte, nicht scrollbare Column unten überlaufen zu
  // lassen (siehe Bericht: bei genau 1050 px blieb der Nachbau in diesem Test
  // bereits vor der Korrektur ohne Überlauf).
  for (final breite in [1050.0, 750.0]) {
    testWidgets(
      'die manuelle Eingabespalte laeuft bei "Am groessten" und leerer Liste '
      'bei ${breite}px nicht ueber',
      (tester) async {
        await zeigeMitManuellerEingabe(
          tester,
          replies: const [],
          breite: breite,
        );

        expect(
          tester.takeException(),
          isNull,
          reason:
              'Die Spalte "Antwortmail des Zentralrufs" stand in einer nicht '
              'scrollbaren Column hinter einer fest 360 px breiten Liste — '
              'bei "Am größten" und schmalem Fenster lief sie unten über.',
        );
      },
    );

    testWidgets('die manuelle Eingabespalte laeuft bei "Am groessten" und drei '
        'erfassten Antworten bei ${breite}px nicht ueber', (tester) async {
      await zeigeMitManuellerEingabe(
        tester,
        replies: _dreiEintraege(),
        breite: breite,
      );

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Wie oben, diesmal mit gefüllter Trefferliste daneben — sie '
            'darf das Panel nicht zusätzlich verengen.',
      );
    });
  }
}
