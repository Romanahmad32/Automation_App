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
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_repository.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_auswahl_signal.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/domain/repositories/versicherer_repository.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_hervorhebung_signal.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';

/// Die Attrappen, die ein Widget-Test des Postfach-Tabs braucht — alles, was
/// die Ansicht **neben** dem Posteingang selbst anfasst.
///
/// Die Attrappen des Posteingangs (`PosteingangTestRepository`,
/// `PosteingangTestPush`) stehen weiterhin in `posteingang_cubit_test.dart`
/// und werden von dort importiert: Sie merken sich, was angefragt wurde, und
/// gehören damit zum Test des Cubits. Hier steht das Gegenteil — Bestände, die
/// nur da sein müssen, damit etwas auf dem Schirm steht.

/// Ein verbundenes Postfach mit den übergebenen erfassten Antworten.
class MailboxTestAntworten implements MailboxRepository {
  MailboxTestAntworten([this.replies = const []]);

  final List<ReceivedReply> replies;

  /// Was quittiert wurde — der Nachweis, dass „Übernehmen" den Treffer
  /// abschließt.
  final List<String> quittiert = [];

  static const MailboxStatus verbunden = MailboxStatus(
    enabled: true,
    configured: true,
    connected: true,
    idleSupported: true,
    lastConnectedAt: null,
    lastReplyAt: null,
    lastError: null,
    receivedCount: 0,
    pendingCount: 0,
  );

  @override
  Future<Either<Failure, MailboxStatus>> getStatus() async => Right(verbunden);

  @override
  Future<Either<Failure, List<ReceivedReply>>> getReplies({
    bool includeAcknowledged = false,
  }) async => Right(replies);

  @override
  Future<Either<Failure, void>> acknowledge(String id) async {
    quittiert.add(id);
    return Right(null);
  }

  @override
  Future<Either<Failure, MailboxConfig>> getConfig() =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, MailboxConfig>> saveConfig(
    MailboxConfigUpdate update,
  ) => throw UnimplementedError();
  @override
  Future<Either<Failure, MailboxConfig>> microsoftSignIn() =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, MailboxConfig>> microsoftSignOut() =>
      throw UnimplementedError();
}

/// Das Versandprotokoll für den Bereich „Gesendet": liefert die übergebenen
/// Einträge, merkt sich das angefragte Limit — oder wirft, wenn [fehler] gilt.
class VersandTestProtokoll implements EmailVersandRepository {
  VersandTestProtokoll({this.eintraege = const [], this.fehler = false});

  final List<VersandEintrag> eintraege;
  final bool fehler;
  final List<int> limits = [];

  @override
  Future<List<VersandEintrag>> ladeAlleVersaende({int limit = 200}) async {
    limits.add(limit);
    if (fehler) throw Exception('Dienst nicht erreichbar');
    return eintraege;
  }

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() async => const [];
  @override
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) async =>
      const [];
  @override
  Future<EmailVersandBereitschaft> ladeBereitschaft() =>
      throw UnimplementedError();
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
  Future<OutlookAnhaenge> ladeOutlookAnhaenge() => throw UnimplementedError();
  @override
  Future<OutlookStand> ladeOutlookStand() async => OutlookStand.unbekannt;
  @override
  Future<void> verwirfAnhang(String pfad) async {}
  @override
  Future<List<OutlookSignatur>> ladeOutlookSignaturen() async => const [];
  @override
  Future<SignaturStand> ladeSignaturStand() async => const SignaturStand();
  @override
  Future<SignaturStand> leseSignatur(String name) async =>
      const SignaturStand();
  @override
  Future<SignaturStand> uebernimmSignatur(String name) async =>
      const SignaturStand();
  @override
  Future<SignaturStand> verwirfSignaturFormat() async => const SignaturStand();
}

/// Ein fester Vorgangsbestand — der [VorgangCubit] lädt ihn im Konstruktor.
class VorgangTestAblage implements VorgangRepository {
  VorgangTestAblage([this.vorgaenge = const []]);

  final List<Vorgang> vorgaenge;

  @override
  Future<List<Vorgang>> loadVorgaenge() async => vorgaenge;
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

/// Wird in Layout-Tests nie aufgerufen — es geht um die Ansicht, nicht um das
/// Auswerten einer eingefügten Mail.
class NieAufgerufenesAuswerten
    implements UseCase<ZentralrufReplyParseResult, ZentralrufReplyInput> {
  @override
  Future<Either<Failure, ZentralrufReplyParseResult>> call(
    ZentralrufReplyInput params,
  ) => throw UnimplementedError();
}

/// Die Versicherer-Wissensbasis; leer reicht, solange kein Test den Abgleich
/// über die Absenderadresse prüft (das tut `vorgangsbezug_erkenner_test.dart`
/// ohne Oberfläche).
class VersichererTestBestand implements VersichererRepository {
  VersichererTestBestand([this.bestand = const []]);

  final List<Versicherer> bestand;

  @override
  Future<List<Versicherer>> ladeVersicherer() async => bestand;
}

/// Registriert, was der Postfach-Tab über `getIt` sucht. Im Test vor dem
/// Aufbau der Ansicht aufrufen, `getIt.reset()` im `tearDown`.
void registriereMailboxBestaende({
  List<Vorgang> vorgaenge = const [],
  List<Versicherer> versicherer = const [],
}) {
  getIt.registerSingleton<MailboxAuswahlSignal>(MailboxAuswahlSignal());
  getIt.registerSingleton<VorgangHervorhebungSignal>(
    VorgangHervorhebungSignal(),
  );
  getIt.registerSingleton<VorgangCubit>(
    VorgangCubit(VorgangTestAblage(vorgaenge), VorgangPersistenzFehlerCubit()),
  );
  // Das Vorgangsdaten-Formular der Zentralruf-Antwort holt sich beide Cubits
  // über getIt — ohne diesen fiele es beim Aufbau um.
  getIt.registerSingleton<VersichererCubit>(
    VersichererCubit(VersichererTestBestand(versicherer)),
  );
}
