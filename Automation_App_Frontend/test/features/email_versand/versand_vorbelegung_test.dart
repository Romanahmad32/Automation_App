import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/repositories/anredebausteine_repository.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/anredebausteine_cubit/anredebausteine_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/domain/repositories/versicherer_repository.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:flutter_test/flutter_test.dart';

/// Nur die Aufrufe, die `EmailEntwurfCubit.starte` tatsächlich braucht
/// (Bereitschaft, Outlook-Stand, Vorwärmen) — der Rest wirft, weil diese
/// Tests ihn nicht anfassen (§4.3 „Antworten": Vorbelegung aus Empfänger,
/// Betreff und Vorgang).
class _StummeVersandRepository implements EmailVersandRepository {
  @override
  Future<EmailVersandBereitschaft> ladeBereitschaft() async =>
      const EmailVersandBereitschaft(
        bereit: true,
        absender: 'kanzlei@example.de',
      );

  @override
  Future<OutlookStand> ladeOutlookStand() async => OutlookStand.unbekannt;

  @override
  Future<void> waermeEntwurfVor() async {}

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
  Future<OutlookAnhaenge> ladeOutlookAnhaenge() => throw UnimplementedError();

  @override
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) =>
      throw UnimplementedError();

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() =>
      throw UnimplementedError();

  @override
  Future<List<VersandEintrag>> ladeAlleVersaende({int limit = 200}) =>
      throw UnimplementedError();

  @override
  Future<void> verwirfAnhang(String pfad) => throw UnimplementedError();

  @override
  Future<List<OutlookSignatur>> ladeOutlookSignaturen() =>
      throw UnimplementedError();

  @override
  Future<SignaturStand> ladeSignaturStand() => throw UnimplementedError();

  @override
  Future<SignaturStand> leseSignatur(String name) => throw UnimplementedError();

  @override
  Future<SignaturStand> uebernimmSignatur(String name) =>
      throw UnimplementedError();

  @override
  Future<SignaturStand> verwirfSignaturFormat() => throw UnimplementedError();
}

class _FakeGetKanzleiSettings implements UseCase<KanzleiSettings, NoParams> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Right(const KanzleiSettings(name: 'Rechtsanwalt Max Muster'));
}

class _FakeGetMandanten implements UseCase<List<Mandant>, NoParams> {
  final List<Mandant> mandanten;
  _FakeGetMandanten(this.mandanten);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async =>
      Right(mandanten);
}

class _FakeUpdateMandant implements UseCase<Mandant, Mandant> {
  @override
  Future<Either<Failure, Mandant>> call(Mandant params) async => Right(params);
}

class _FakeVersichererRepository implements VersichererRepository {
  @override
  Future<List<Versicherer>> ladeVersicherer() async => const [];
}

class _FakeAnredebausteine implements AnredebausteineRepository {
  @override
  Future<List<Anredebaustein>> ladeAnredebausteine() async => const [];
  @override
  Future<Anredebaustein> lege(Anredebaustein baustein) async => baustein;
  @override
  Future<Anredebaustein> aktualisiere(Anredebaustein baustein) async =>
      baustein;
  @override
  Future<void> loesche(int id) async {}
}

void main() {
  final mandant = Mandant(
    id: 7,
    anrede: Anrede.herr,
    vorname: 'Klaus',
    nachname: 'Müller',
    emailAdresse: 'k.mueller@example.de',
    erstelltAm: DateTime(2026, 1, 1),
  );

  final vorgang = Vorgang(
    referenz: '84/26 C03_GG-XY 123',
    angefragtAm: DateTime(2026, 6, 20),
    laufendeNummer: 84,
    jahr: '26',
    abteilung: 'C03',
    mandantId: 7,
    mandantName: 'Klaus Müller',
    gegner: 'HUK-COBURG',
  );

  EmailEntwurfCubit baue({List<Mandant> mandanten = const []}) =>
      EmailEntwurfCubit(
        _StummeVersandRepository(),
        _FakeGetKanzleiSettings(),
        _FakeGetMandanten(mandanten),
        VersichererCubit(_FakeVersichererRepository()),
        AnredebausteineCubit(_FakeAnredebausteine()),
        _FakeUpdateMandant(),
      );

  test('ohne Vorgaben bleibt die Vorbelegung wie heute', () async {
    final cubit = baue(mandanten: [mandant]);

    await cubit.starte(vorgang: vorgang);

    expect(cubit.state.entwurf.an, ['k.mueller@example.de']);
    // Ohne Vorgabe entsteht der Betreff wie bisher aus dem Vorgang (kein
    // leerer Betreff, wenn ein Vorgang vorliegt) — die Vorgabe greift erst,
    // wenn `betreffVorgabe` gesetzt ist (siehe Test unten).
    expect(cubit.state.entwurf.betreff, contains('84/26 C03'));
    await cubit.close();
  });

  test('übernimmt Empfänger, Betreff und Vorgang aus den Vorgaben (§4.3 '
      '„Antworten")', () async {
    final cubit = baue(mandanten: [mandant]);

    await cubit.starte(
      vorgang: vorgang,
      empfaengerVorauswahl: const ['schaden@huk.de'],
      betreffVorgabe: 'AW: Unfall vom 12.03.',
    );

    expect(cubit.state.entwurf.an, contains('schaden@huk.de'));
    expect(cubit.state.entwurf.an, contains('k.mueller@example.de'));
    expect(cubit.state.entwurf.betreff, 'AW: Unfall vom 12.03.');
    expect(cubit.state.vorgang, vorgang);
    await cubit.close();
  });

  test('wirkt auch ohne erkannten Vorgang — das leere Anschreiben bekommt '
      'trotzdem Empfänger und Betreff', () async {
    final cubit = baue();

    await cubit.starte(
      empfaengerVorauswahl: const ['schaden@huk.de'],
      betreffVorgabe: 'AW: Unfall vom 12.03.',
    );

    expect(cubit.state.vorgang, isNull);
    expect(cubit.state.entwurf.an, ['schaden@huk.de']);
    expect(cubit.state.entwurf.betreff, 'AW: Unfall vom 12.03.');
    await cubit.close();
  });
}
