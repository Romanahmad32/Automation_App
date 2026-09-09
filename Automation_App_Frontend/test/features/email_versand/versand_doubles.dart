import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/repositories/anredebausteine_repository.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/domain/repositories/grussformeln_repository.dart';
import 'package:automation_app/features/email_versand/domain/repositories/mail_vorlagen_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/grussformeln_cubit/grussformeln_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/mail_vorlagen_cubit/mail_vorlagen_cubit.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/domain/repositories/versicherer_repository.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart';

/// Die Attrappen, die ein **Widget**-Test des Versanddialogs braucht.
///
/// Eigene Datei, weil es viele sind und keine davon etwas erzählt: Der Dialog
/// zieht seine Bestände über `getIt` (Vorlagen, Anreden, Zusatzgrüße, Vorgänge)
/// und den Entwurf über sechs Abhängigkeiten. Ein Test, der das alles
/// mitschleppt, versteckt seine eigene Aussage darin.
///
/// Der Unit-Test des Cubits (`email_entwurf_cubit_test.dart`) hat bewusst
/// **eigene** Attrappen: Er prüft, was der Cubit aus ihnen macht, und braucht
/// deshalb Attrappen, die sich merken, was ankam. Hier soll gar nichts
/// ankommen — hier soll nur etwas auf dem Schirm stehen.
class StummerVersanddienst implements EmailVersandRepository {
  final bool bereit;

  StummerVersanddienst({this.bereit = true});

  @override
  Future<EmailVersandBereitschaft> ladeBereitschaft() async =>
      EmailVersandBereitschaft(
        bereit: bereit,
        absender: 'kanzlei@example.de',
        hinweis: bereit ? null : 'Kein Postfach-Zugang hinterlegt.',
      );

  @override
  Future<EmailVersandErgebnis> sende(
    EmailEntwurf entwurf, {
    required String absenderName,
  }) async => EmailVersandErgebnis(
    gesendetAm: DateTime(2026, 9, 6),
    empfaenger: entwurf.alleEmpfaenger,
    imGesendetOrdner: true,
  );

  @override
  Future<EmailEntwurfErgebnis> oeffneEntwurf(
    EmailEntwurf entwurf, {
    required String absenderName,
  }) async => const EmailEntwurfErgebnis(weg: 'outlook');

  @override
  Future<void> waermeEntwurfVor() async {}

  @override
  Future<OutlookAnhaenge> ladeOutlookAnhaenge() async =>
      const OutlookAnhaenge(pfade: [], betreff: '', absender: '');

  @override
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) async =>
      const [];

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() async => const [];

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

class StummeKanzleidaten implements UseCase<KanzleiSettings, NoParams> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Right(const KanzleiSettings(name: 'Rechtsanwalt Max Muster'));
}

class StummesMandantenregister implements UseCase<List<Mandant>, NoParams> {
  final List<Mandant> mandanten;

  StummesMandantenregister([this.mandanten = const []]);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async =>
      Right(mandanten);
}

class StummerMandantSchreiber implements UseCase<Mandant, Mandant> {
  @override
  Future<Either<Failure, Mandant>> call(Mandant params) async => Right(params);
}

class StummeVersicherer implements VersichererRepository {
  @override
  Future<List<Versicherer>> ladeVersicherer() async => const [];
}

class StummerAnredebestand implements AnredebausteineRepository {
  final List<Anredebaustein> bestand;

  StummerAnredebestand([this.bestand = const []]);

  @override
  Future<List<Anredebaustein>> ladeAnredebausteine() async => bestand;

  @override
  Future<Anredebaustein> lege(Anredebaustein baustein) async => baustein;

  @override
  Future<Anredebaustein> aktualisiere(Anredebaustein baustein) async =>
      baustein;

  @override
  Future<void> loesche(int id) async {}
}

class StummerGrussbestand implements GrussformelnRepository {
  @override
  Future<List<Grussformel>> ladeGrussformeln() async => const [];

  @override
  Future<Grussformel> lege(Grussformel grussformel) async => grussformel;

  @override
  Future<Grussformel> aktualisiere(Grussformel grussformel) async =>
      grussformel;

  @override
  Future<void> loesche(int id) async {}
}

class StummerVorlagenbestand implements MailVorlagenRepository {
  final List<MailVorlage> bestand;

  StummerVorlagenbestand([this.bestand = const []]);

  @override
  Future<List<MailVorlage>> ladeVorlagen() async => bestand;

  @override
  Future<MailVorlage> lege(MailVorlage vorlage) async => vorlage;

  @override
  Future<MailVorlage> aktualisiere(MailVorlage vorlage) async => vorlage;

  @override
  Future<void> loesche(int id) async {}
}

class StummeVorgangsablage implements VorgangRepository {
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

/// Registriert alles, was der Versanddialog über `getIt` sucht. Im `setUp`
/// aufrufen, `getIt.reset()` im `tearDown`.
void registriereVersandBestaende({
  List<MailVorlage> vorlagen = const [],
  List<Anredebaustein> anreden = const [],
}) {
  getIt.registerLazySingleton<MailVorlagenCubit>(
    () => MailVorlagenCubit(StummerVorlagenbestand(vorlagen)),
  );
  getIt.registerLazySingleton<GrussformelnCubit>(
    () => GrussformelnCubit(StummerGrussbestand()),
  );
  getIt.registerLazySingleton<AnredebausteineCubit>(
    () => AnredebausteineCubit(StummerAnredebestand(anreden)),
  );
  getIt.registerLazySingleton<VorgangCubit>(
    () => VorgangCubit(StummeVorgangsablage(), VorgangPersistenzFehlerCubit()),
  );
}

/// Der Entwurfs-Cubit mit lauter stummen Quellen — der Zustand, auf dem die
/// Oberfläche gebaut wird.
EmailEntwurfCubit stummerEntwurfCubit({
  bool bereit = true,
  List<Mandant> mandanten = const [],
  List<Anredebaustein> anreden = const [],
}) => EmailEntwurfCubit(
  StummerVersanddienst(bereit: bereit),
  StummeKanzleidaten(),
  StummesMandantenregister(mandanten),
  VersichererCubit(StummeVersicherer()),
  AnredebausteineCubit(StummerAnredebestand(anreden)),
  StummerMandantSchreiber(),
);
