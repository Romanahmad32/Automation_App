import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/domain/repositories/anredebausteine_repository.dart';
import 'package:automation_app/features/email_versand/domain/repositories/grussformeln_repository.dart';
import 'package:automation_app/features/email_versand/domain/repositories/mail_vorlagen_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/mail_vorlagen_cubit/mail_vorlagen_cubit.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_repository.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_config_bloc/mailbox_config_bloc.dart';
import 'package:automation_app/features/mailbox/presentation/views/mailbox_access_view.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../settings/kanzlei_settings_doubles.dart';

/// Der gespeicherte Postfach-Zugang muss in der Maske stehen, **wann immer**
/// sie aufgeht — auch dann, wenn der Bloc schon geladen war.
///
/// Genau dieser Fall ist hier der Normalfall, nicht die Ausnahme: Die Maske
/// liegt im zweiten Reiter der Einstellungen und wird erst gebaut, wenn jemand
/// ihn antippt. Bis dahin hat der `MailboxConfigBloc` — angestoßen beim Aufbau
/// der Seite — längst `Loaded` gemeldet. Ein `BlocConsumer.listener` bekommt
/// den Zustand, der beim Mounten schon dasteht, **nicht** zu sehen; er hört nur
/// Übergänge.
///
/// Was dann passiert, ist stumm und teuer: Das Formular zeigt seine
/// Vorgabewerte (`imap.ionos.de`, Port 993, kein Benutzer, Überwachung aus),
/// sieht aber aus wie ein geladener Stand. Wer darauf „Speichern" drückt,
/// schreibt sie über den echten Zugang.
///
/// Dasselbe Muster, dieselbe Ursache wie bei der Signatur in
/// `mail_signatur_anzeige_test.dart`. Der gemeinsame Baustein dagegen ist
/// `StandNachziehen` (`core/general_widgets/`).
class FesterMailboxZugang implements MailboxRepository {
  final MailboxConfig config;

  FesterMailboxZugang(this.config);

  @override
  Future<Either<Failure, MailboxConfig>> getConfig() async => Right(config);

  @override
  Future<Either<Failure, MailboxConfig>> saveConfig(
    MailboxConfigUpdate update,
  ) async => Right(config);

  @override
  Future<Either<Failure, MailboxConfig>> microsoftSignIn() async =>
      Right(config);

  @override
  Future<Either<Failure, MailboxConfig>> microsoftSignOut() async =>
      Right(config);

  @override
  Future<Either<Failure, MailboxStatus>> getStatus() async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<ReceivedReply>>> getReplies({
    bool includeAcknowledged = false,
  }) async => Right([]);

  @override
  Future<Either<Failure, void>> acknowledge(String id) async => Right(null);
}

/// Die Signatursektion hängt unten in derselben Maske und fragt beim Aufgehen
/// den Versanddienst nach dem Signaturstand. Hier soll sie nur nicht im Weg
/// stehen.
class StummerVersanddienst implements EmailVersandRepository {
  @override
  Future<SignaturStand> ladeSignaturStand() async => const SignaturStand();

  @override
  Future<EmailVersandBereitschaft> ladeBereitschaft() async =>
      const EmailVersandBereitschaft(bereit: false);

  @override
  Future<EmailVersandErgebnis> sende(
    EmailEntwurf entwurf, {
    required String absenderName,
  }) => throw UnimplementedError();

  @override
  Future<EmailEntwurfErgebnis> oeffneEntwurf(
    EmailEntwurf entwurf, {
    required String absenderName,
  }) => throw UnimplementedError();

  @override
  Future<void> waermeEntwurfVor() async {}

  @override
  Future<OutlookAnhaenge> ladeOutlookAnhaenge() async =>
      const OutlookAnhaenge();

  @override
  Future<OutlookStand> ladeOutlookStand() async => OutlookStand.unbekannt;

  @override
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) async =>
      const [];

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() async => const [];

  @override
  Future<void> verwirfAnhang(String pfad) async {}

  @override
  Future<List<OutlookSignatur>> ladeOutlookSignaturen() async => const [];

  @override
  Future<SignaturStand> leseSignatur(String name) async =>
      const SignaturStand();

  @override
  Future<SignaturStand> uebernimmSignatur(String name) async =>
      const SignaturStand();

  @override
  Future<SignaturStand> verwirfSignaturFormat() async => const SignaturStand();
}

/// Daneben die Verwaltung der persoenlichen Gruesse (§4.7, §7.1) — auch sie
/// holt beim Aufgehen; hier bleibt der Bestand leer.
/// Ebenfalls unten in derselben Maske: die Verwaltung der Anredeanfaenge
/// (§4.7, §7.1). Sie holt den Bestand beim Aufgehen; hier bleibt er leer.
class StummerAnredeDienst implements AnredebausteineRepository {
  @override
  Future<List<Anredebaustein>> ladeAnredebausteine() async => const [];

  @override
  Future<Anredebaustein> lege(Anredebaustein baustein) =>
      throw UnimplementedError();

  @override
  Future<Anredebaustein> aktualisiere(Anredebaustein baustein) =>
      throw UnimplementedError();

  @override
  Future<void> loesche(int id) => throw UnimplementedError();
}

class StummerGrussDienst implements GrussformelnRepository {
  @override
  Future<List<Grussformel>> ladeGrussformeln() async => const [];

  @override
  Future<Grussformel> lege(Grussformel grussformel) =>
      throw UnimplementedError();

  @override
  Future<Grussformel> aktualisiere(Grussformel grussformel) =>
      throw UnimplementedError();

  @override
  Future<void> loesche(int id) => throw UnimplementedError();
}

/// Ebenfalls unten in derselben Maske: die Verwaltung der Mail-Textvorlagen
/// (§4.7). Sie holt den Bestand beim Aufgehen; hier bleibt er leer.
class StummerVorlagenDienst implements MailVorlagenRepository {
  @override
  Future<List<MailVorlage>> ladeVorlagen() async => const [];

  @override
  Future<MailVorlage> lege(MailVorlage vorlage) => throw UnimplementedError();

  @override
  Future<MailVorlage> aktualisiere(MailVorlage vorlage) =>
      throw UnimplementedError();

  @override
  Future<void> loesche(int id) => throw UnimplementedError();
}

void main() {
  const gespeichert = MailboxConfig(
    enabled: true,
    host: 'imap.ionos.de',
    port: 993,
    username: 'kanzlei@example.de',
    appPasswordSet: true,
    folder: 'INBOX',
    subjectFilter: 'Zentralruf',
  );

  setUp(() {
    getIt.registerSingleton<EmailVersandRepository>(StummerVersanddienst());
    getIt.registerLazySingleton<MailVorlagenCubit>(
      () => MailVorlagenCubit(StummerVorlagenDienst()),
    );
    getIt.registerLazySingleton<GrussformelnCubit>(
      () => GrussformelnCubit(StummerGrussDienst()),
    );
    getIt.registerLazySingleton<AnredebausteineCubit>(
      () => AnredebausteineCubit(StummerAnredeDienst()),
    );
  });

  tearDown(() => getIt.reset());

  /// Der Wert, der beim Speichern gelesen wird — nicht irgendein Text auf dem
  /// Schirm.
  Object? imFeld(WidgetTester tester, String name) => tester
      .widget<ReactiveForm>(find.byType(ReactiveForm).first)
      .formGroup
      .control(name)
      .value;

  Future<MailboxConfigBloc> zeige(
    WidgetTester tester, {
    required bool schonGeladen,
  }) async {
    final bloc = MailboxConfigBloc(FesterMailboxZugang(gespeichert));
    addTearDown(bloc.close);
    final settings = KanzleiSettingsBloc(
      FesterSettingsAbruf(const KanzleiSettings(name: 'Kanzlei Ahmad')),
      DurchreichendesSpeichern(),
    );
    addTearDown(settings.close);
    settings.add(const LoadKanzleiSettingsEvent());

    if (schonGeladen) {
      final fertig = bloc.stream.firstWhere((s) => s is MailboxConfigLoaded);
      bloc.add(const LoadMailboxConfigEvent());
      await fertig;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: bloc),
              BlocProvider.value(value: settings),
            ],
            child: const MailboxAccessView(),
          ),
        ),
      ),
    );

    if (!schonGeladen) bloc.add(const LoadMailboxConfigEvent());
    await tester.pumpAndSettle();
    return bloc;
  }

  testWidgets('zeigt den gespeicherten Zugang beim ersten Öffnen', (
    tester,
  ) async {
    await zeige(tester, schonGeladen: false);

    expect(imFeld(tester, 'username'), gespeichert.username);
    expect(imFeld(tester, 'enabled'), isTrue);
  });

  testWidgets('zeigt ihn auch, wenn der Bloc schon geladen war', (
    tester,
  ) async {
    // Der Regelfall: zweiter Reiter, angetippt, nachdem die Seite fertig
    // geladen hat. Es kommt kein Übergang mehr, aus dem die Maske den Stand
    // aufschnappen könnte.
    await zeige(tester, schonGeladen: true);

    expect(
      imFeld(tester, 'username'),
      gespeichert.username,
      reason:
          'Die Maske zeigt ihre Vorgabewerte statt des geladenen Zugangs — '
          'ein Klick auf Speichern schriebe sie über den echten.',
    );
    expect(imFeld(tester, 'enabled'), isTrue);
  });
}
