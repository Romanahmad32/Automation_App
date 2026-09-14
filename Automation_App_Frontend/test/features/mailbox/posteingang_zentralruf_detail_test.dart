import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:automation_app/core/theme/presentation/theme.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_zentralruf_detail.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/domain/repositories/versicherer_repository.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `VorgangsdatenForm`/`MailboxVorgangZuordnung` fragen beide
/// `getIt<VorgangCubit>()` — hier bleibt der Bestand leer, es geht nur um
/// dieses Widget.
class _LeererVorgangsbestand implements VorgangRepository {
  @override
  Future<List<Vorgang>> loadVorgaenge() async => const [];
  @override
  Future<Vorgang> upsertVorgang(Vorgang vorgang) async => vorgang;
  @override
  Future<void> deleteVorgang(
    String referenz, {
    bool registerzeileBehalten = true,
  }) async {}
  @override
  Future<Vorgang?> setzeEntwurf(
    String referenz,
    VorgangEntwurf? entwurf,
  ) async => null;
  @override
  Future<Vorgang?> abschliessenVorgang(String referenz) async => null;
  @override
  Future<Vorgang?> aendereReferenz(String von, String nach) async => null;
}

/// `VorgangsdatenForm` fragt beim Aufbau `getIt<VersichererCubit>()` für die
/// Lückenfüllung — hier bleibt die Wissensbasis leer.
class _LeereVersicherer implements VersichererRepository {
  @override
  Future<List<Versicherer>> ladeVersicherer() async => const [];
}

ReceivedReply _antwort({
  bool acknowledged = false,
  List<String> warnings = const [],
}) => ReceivedReply(
  id: 'r1',
  receivedAt: DateTime(2026, 9, 10, 8, 30),
  subject: 'Auskunft zu Ihrer Anfrage',
  from: 'zentralruf@gdv-dienstleistungs-gmbh.de',
  acknowledged: acknowledged,
  warnings: warnings,
  rawText: 'Sehr geehrte Damen und Herren, ...',
  data: const ZentralrufReplyData(
    referenz: '123/2026 K_HG-E 1427',
    versichererName: 'HUK-Coburg Allgemeine Versicherung AG',
  ),
);

void main() {
  setUp(() {
    getIt.registerLazySingleton<VorgangCubit>(
      () => VorgangCubit(
        _LeererVorgangsbestand(),
        VorgangPersistenzFehlerCubit(),
      ),
    );
    getIt.registerLazySingleton<VersichererCubit>(
      () => VersichererCubit(_LeereVersicherer()),
    );
  });

  tearDown(() => getIt.reset());

  Future<void> pumpDetail(
    WidgetTester tester, {
    required ReceivedReply antwort,
    void Function(ReceivedReply, ZentralrufReplyData, String?)? onUebernehmen,
    VoidCallback? onMailAnzeigen,
    double breite = 900,
    Schriftstufe schriftstufe = Schriftstufe.normal,
  }) async {
    tester.view.physicalSize = Size(breite, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: MaterialTheme(
          ThemeData.light().textTheme,
          schriftstufe: schriftstufe,
        ).light(),
        home: Scaffold(
          body: PosteingangZentralrufDetail(
            antwort: antwort,
            onUebernehmen: onUebernehmen ?? (_, _, _) {},
            onMailAnzeigen: onMailAnzeigen ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'zeigt im Kopf "offen", solange die Antwort nicht uebernommen ist',
    (tester) async {
      await pumpDetail(tester, antwort: _antwort(acknowledged: false));

      expect(find.text('Zentralruf-Antwort · offen'), findsOneWidget);
      expect(find.text('Zentralruf-Antwort · übernommen'), findsNothing);
    },
  );

  testWidgets('zeigt im Kopf "uebernommen", wenn die Antwort erledigt ist', (
    tester,
  ) async {
    await pumpDetail(tester, antwort: _antwort(acknowledged: true));

    expect(find.text('Zentralruf-Antwort · übernommen'), findsOneWidget);
    expect(find.text('Zentralruf-Antwort · offen'), findsNothing);
  });

  testWidgets('zeigt Versicherer, Datum und das Vorgangsdaten-Formular', (
    tester,
  ) async {
    await pumpDetail(tester, antwort: _antwort());

    // Der Name steht zweimal auf dem Schirm: im Kopf dieses Panels und im
    // Versichererfeld des wiederverwendeten VorgangsdatenForm darunter — eben
    // weil das Formular eingebunden und nicht abgeschrieben ist.
    expect(find.text('HUK-Coburg Allgemeine Versicherung AG'), findsWidgets);
    expect(find.text('10.09.2026 08:30'), findsOneWidget);
    // Das wiederverwendete VorgangsdatenForm, nicht kopiert.
    expect(find.text('Vorgangsdaten'), findsOneWidget);
    expect(find.text('Übernehmen und Vorlage ausfüllen'), findsOneWidget);
  });

  testWidgets('"Mail anzeigen" ruft den Callback auf', (tester) async {
    var aufgerufen = false;
    await pumpDetail(
      tester,
      antwort: _antwort(),
      onMailAnzeigen: () => aufgerufen = true,
    );

    await tester.tap(find.text('Mail anzeigen'));
    await tester.pump();

    expect(aufgerufen, isTrue);
  });

  testWidgets('laeuft bei "Am groessten" und 420 px nicht ueber', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      antwort: _antwort(
        warnings: const ['Kennzeichen passt nicht zur Referenz'],
      ),
      breite: 420,
      schriftstufe: Schriftstufe.amGroessten,
    );

    expect(tester.takeException(), isNull);
  });
}
