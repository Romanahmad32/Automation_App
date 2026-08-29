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
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/entwurf_quellen.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Rückfallwege der vier Nachschlagestellen des Entwurfs (§4.7).
///
/// Alle vier teilen dieselbe Haltung: **Ein Fehler beim Laden darf den Entwurf
/// nicht verhindern.** Ohne Kanzleidaten fehlt die Unterschrift, ohne Mandant
/// ein Adressvorschlag, ohne Bereitschaft die Auskunft, ob gesendet werden
/// kann — alles verschmerzlich. Ein Dialog, der gar nicht erst aufgeht, wäre es
/// nicht. Genau diese Zusicherung steht hier.
class StoerrischerVersandDienst implements EmailVersandRepository {
  /// Was Bereitschaft und Outlook-Stand werfen sollen; null = alles gut.
  final Object? wirft;

  StoerrischerVersandDienst({this.wirft});

  @override
  Future<EmailVersandBereitschaft> ladeBereitschaft() async {
    if (wirft != null) throw wirft!;
    return const EmailVersandBereitschaft(
      bereit: true,
      absender: 'kanzlei@example.de',
    );
  }

  @override
  Future<OutlookStand> ladeOutlookStand() async {
    if (wirft != null) throw wirft!;
    return const OutlookStand(steuerbar: true);
  }

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
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) async =>
      const [];

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() async => const [];

  @override
  Future<void> verwirfAnhang(String pfad) async {}

  @override
  Future<List<OutlookSignatur>> ladeOutlookSignaturen() async => const [];

  @override
  Future<SignaturStand> ladeSignaturStand() async => const SignaturStand();

  @override
  Future<SignaturStand> uebernimmSignatur(String name) async =>
      const SignaturStand();

  @override
  Future<SignaturStand> verwirfSignaturFormat() async => const SignaturStand();
}

class KanzleiAbruf implements UseCase<KanzleiSettings, NoParams> {
  final Either<Failure, KanzleiSettings> ergebnis;

  const KanzleiAbruf(this.ergebnis);

  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      ergebnis;
}

class MandantenAbruf implements UseCase<List<Mandant>, NoParams> {
  final Either<Failure, List<Mandant>> ergebnis;

  /// Wie oft das Register befragt wurde — ohne Mandant am Vorgang gar nicht.
  int aufrufe = 0;

  MandantenAbruf(this.ergebnis);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async {
    aufrufe++;
    return ergebnis;
  }
}

void main() {
  final mandant = Mandant(
    id: 1,
    anrede: Anrede.herr,
    vorname: 'Klaus',
    nachname: 'Müller',
    erstelltAm: DateTime(2026, 3, 12),
  );

  Vorgang vorgang({int? mandantId}) => Vorgang(
    referenz: '84/2026 C03_HG-E 1427',
    angefragtAm: DateTime(2026, 3, 12),
    kennzeichen: 'HG-E 1427',
    mandantId: mandantId,
  );

  EntwurfQuellen quellen({
    Object? dienstWirft,
    Either<Failure, KanzleiSettings>? kanzlei,
    MandantenAbruf? mandanten,
  }) => EntwurfQuellen(
    StoerrischerVersandDienst(wirft: dienstWirft),
    KanzleiAbruf(
      kanzlei ?? Right(const KanzleiSettings(name: 'Rechtsanwalt Max Muster')),
    ),
    mandanten ?? MandantenAbruf(Right([mandant])),
  );

  test('ohne Kanzleidaten bleibt der leere Satz — nicht ein Fehler', () async {
    final gelesen = await quellen(
      kanzlei: Left(LocalFailure(message: 'Datenbank gesperrt')),
    ).kanzlei();

    expect(gelesen, KanzleiSettings.empty);
  });

  test('der Mandant am Vorgang wird herausgesucht', () async {
    final gelesen = await quellen().mandantZu(vorgang(mandantId: 1));

    expect(gelesen, mandant);
  });

  test('ohne Vorgang und ohne Mandant-Id fragt niemand das Register', () async {
    final register = MandantenAbruf(Right([mandant]));

    expect(await quellen(mandanten: register).mandantZu(null), isNull);
    expect(await quellen(mandanten: register).mandantZu(vorgang()), isNull);
    expect(register.aufrufe, 0);
  });

  test('ein unerreichbares Register kostet nur den Adressvorschlag', () async {
    final gelesen = await quellen(
      mandanten: MandantenAbruf(Left(ServerFailure(message: 'kein Dienst'))),
    ).mandantZu(vorgang(mandantId: 1));

    expect(gelesen, isNull);
  });

  test('ein gelöschter Mandant hinterlässt keinen Vorschlag', () async {
    final gelesen = await quellen(
      mandanten: MandantenAbruf(Right(const <Mandant>[])),
    ).mandantZu(vorgang(mandantId: 1));

    expect(gelesen, isNull);
  });

  test('ein stummer Postausgang meldet sich, bevor der Anwalt tippt', () async {
    final stand = await quellen(
      dienstWirft: Exception('Der Dienst antwortet nicht.'),
    ).bereitschaft();

    expect(stand.bereit, isFalse);
    // Ohne das vorangestellte „Exception:" — der Text steht so vor dem Anwalt.
    expect(
      stand.hinweis,
      'Der Postausgang ist nicht erreichbar: Der Dienst antwortet nicht.',
    );
  });

  test('ohne Antwort zum Outlook-Stand wird nichts abgeschaltet', () async {
    final stand = await quellen(
      dienstWirft: Exception('Der Dienst antwortet nicht.'),
    ).outlookStand();

    expect(stand, OutlookStand.unbekannt);
    // „unbekannt" heißt steuerbar: Es wird nichts behauptet und kein Knopf
    // weggenommen, solange der Dienst nicht geantwortet hat.
    expect(stand.steuerbar, isTrue);
  });
}
