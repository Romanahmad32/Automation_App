import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/entities/anrede_neutral_grund.dart';
import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
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
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_auswahl.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/domain/repositories/versicherer_repository.dart';
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVersandRepository implements EmailVersandRepository {
  final bool bereit;
  final Object? wirft;

  /// Was der Entwurfsweg melden soll: "outlook" im Regelfall, "datei" wenn
  /// Outlook fehlt.
  final String entwurfWeg;

  EmailEntwurf? gesendet;
  EmailEntwurf? uebergeben;
  String? absenderName;

  _FakeVersandRepository({
    this.bereit = true,
    this.wirft,
    this.entwurfWeg = 'outlook',
  });

  @override
  Future<EmailEntwurfErgebnis> oeffneEntwurf(
    EmailEntwurf entwurf, {
    required String absenderName,
  }) async {
    if (wirft != null) throw wirft!;
    uebergeben = entwurf;
    return EmailEntwurfErgebnis(
      weg: entwurfWeg,
      hinweis: entwurfWeg == 'outlook' ? null : 'Outlook war nicht erreichbar.',
    );
  }

  /// Wie oft die Oberfläche Outlook vorwärmen liess.
  int vorgewaermt = 0;

  /// Was Outlook auf die Frage nach den Anhaengen der offenen Nachricht liefert.
  List<String> outlookAnhaenge = const [];

  /// Die Nachricht, aus der die Anhaenge stammen.
  String outlookBetreff = 'AW: Unfall vom 12.03.';

  /// Die Pfade, deren Datei die Oberflaeche wegwerfen liess.
  final List<String> verworfen = [];

  @override
  Future<OutlookStand> ladeOutlookStand() async => OutlookStand.unbekannt;

  @override
  Future<List<VersandEintrag>> ladeVersandProtokoll(String referenz) async =>
      const [];

  @override
  Future<List<VersandEintrag>> ladeLetzteVersaende() async => const [];

  @override
  Future<void> verwirfAnhang(String pfad) async => verworfen.add(pfad);

  @override
  Future<OutlookAnhaenge> ladeOutlookAnhaenge() async {
    if (wirft != null) throw wirft!;
    return OutlookAnhaenge(
      pfade: outlookAnhaenge,
      betreff: outlookAnhaenge.isEmpty ? '' : outlookBetreff,
      absender: 'gegner@example.de',
      ausOffenemFenster: true,
    );
  }

  @override
  Future<void> waermeEntwurfVor() async => vorgewaermt++;

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
  }) async {
    if (wirft != null) throw wirft!;
    gesendet = entwurf;
    this.absenderName = absenderName;
    return EmailVersandErgebnis(
      gesendetAm: DateTime(2026, 8, 25, 14, 12),
      empfaenger: entwurf.alleEmpfaenger,
      imGesendetOrdner: true,
    );
  }
}

class _FakeGetKanzleiSettings implements UseCase<KanzleiSettings, NoParams> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Right(const KanzleiSettings(name: 'Rechtsanwalt Max Muster'));
}

class _FakeGetMandanten implements UseCase<List<Mandant>, NoParams> {
  final List<Mandant> mandanten;
  int aufrufe = 0;

  _FakeGetMandanten(this.mandanten);

  @override
  Future<Either<Failure, List<Mandant>>> call(NoParams params) async {
    aufrufe++;
    return Right(mandanten);
  }
}

/// Der Schreibweg ins Mandantenregister. Merkt sich, was ankam, und kann
/// scheitern — beides braucht der Nachtrag der Anredeart (§4.7, §5.1).
class _FakeUpdateMandant implements UseCase<Mandant, Mandant> {
  final bool scheitert;

  Mandant? geschrieben;

  _FakeUpdateMandant({this.scheitert = false});

  @override
  Future<Either<Failure, Mandant>> call(Mandant params) async {
    geschrieben = params;
    return scheitert
        ? Left(LocalFailure(message: 'Datenbank gesperrt'))
        : Right(params);
  }
}

class _FakeVersichererRepository implements VersichererRepository {
  @override
  Future<List<Versicherer>> ladeVersicherer() async => const [];
}

/// Der Anredebestand. Ein echter Cubit mit gefaelschtem Repository: Der
/// Entwurf liest daraus die Vorgabe, und genau die soll geprueft werden.
class _FakeAnredebausteine implements AnredebausteineRepository {
  final List<Anredebaustein> bestand;

  _FakeAnredebausteine(this.bestand);

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

void main() {
  /// Der Ausgangsbestand des Dienstes: „Sehr geehrter" reproduziert genau die
  /// Anrede, die die App vor dem 02.09.2026 fest erzeugt hat.
  const sehrGeehrt = Anredebaustein(
    id: 1,
    maennlich: 'Sehr geehrter',
    weiblich: 'Sehr geehrte',
    neutral: 'Sehr geehrte',
  );

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
    antwort: const ZentralrufReplyData(
      versichererName: 'HUK-COBURG',
      versichererEmail: 'schaden@huk.de',
    ),
  );

  ({
    EmailEntwurfCubit cubit,
    _FakeGetMandanten register,
    _FakeUpdateMandant schreiber,
  })
  baue(
    _FakeVersandRepository repository, {
    List<Mandant> mandanten = const [],
    List<Anredebaustein> anreden = const [sehrGeehrt],
    bool schreibenScheitert = false,
  }) {
    final register = _FakeGetMandanten(mandanten);
    final schreiber = _FakeUpdateMandant(scheitert: schreibenScheitert);
    return (
      cubit: EmailEntwurfCubit(
        repository,
        _FakeGetKanzleiSettings(),
        register,
        VersichererCubit(_FakeVersichererRepository()),
        AnredebausteineCubit(_FakeAnredebausteine(anreden)),
        schreiber,
      ),
      register: register,
      schreiber: schreiber,
    );
  }

  test('starte belegt Empfänger, Anhänge und Bereitschaft vor', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);

    await gebaut.cubit.starte(
      vorgang: vorgang,
      anhangPfade: const ['C:/Akte/Brief.pdf'],
    );

    expect(gebaut.cubit.state.entwurf.an, [
      'k.mueller@example.de',
      'schaden@huk.de',
    ]);
    expect(gebaut.cubit.state.entwurf.anhangPfade, ['C:/Akte/Brief.pdf']);
    expect(gebaut.cubit.state.bereitschaft?.absender, 'kanzlei@example.de');
    expect(gebaut.cubit.state.kannSenden, isTrue);
    await gebaut.cubit.close();
  });

  test('löst den Mandanten selbst aus dem Vorgang auf', () async {
    // Damit der Aufrufer (Postfach) das Register nicht selbst befragen muss.
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);

    await gebaut.cubit.starte(vorgang: vorgang);

    expect(gebaut.register.aufrufe, 1);
    expect(
      gebaut.cubit.state.vorschlaege.map((v) => v.adresse),
      contains('k.mueller@example.de'),
    );
    await gebaut.cubit.close();
  });

  test('ohne Vorgang bleibt das Register unbehelligt', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);

    await gebaut.cubit.starte();

    expect(gebaut.register.aufrufe, 0);
    expect(gebaut.cubit.state.entwurf.an, isEmpty);
    expect(gebaut.cubit.state.entwurf.betreff, isEmpty);
    // Der Knopf bleibt anfassbar -- was fehlt, sagt die Pruefung beim Druecken
    // (§4.7), nicht ein abgeblendeter Knopf ohne Begruendung.
    expect(gebaut.cubit.state.kannSenden, isTrue);
    expect(gebaut.cubit.state.pruefung.vollstaendig, isFalse);
    expect(gebaut.cubit.istVersandbereit(), isFalse);
    expect(await gebaut.cubit.senden(), isFalse);
    await gebaut.cubit.close();
  });

  test('ohne Postfach-Zugang bleibt Senden gesperrt', () async {
    final gebaut = baue(
      _FakeVersandRepository(bereit: false),
      mandanten: [mandant],
    );

    await gebaut.cubit.starte(
      vorgang: vorgang,
      anhangPfade: const ['C:/Akte/Brief.pdf'],
    );

    expect(gebaut.cubit.state.kannSenden, isFalse);
    expect(
      gebaut.cubit.state.bereitschaft?.hinweis,
      contains('Postfach-Zugang'),
    );
    await gebaut.cubit.close();
  });

  test('die Anrede folgt dem Empfängerkreis', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);
    expect(gebaut.cubit.state.entwurf.text, startsWith('Sehr geehrte Damen'));

    gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

    expect(
      gebaut.cubit.state.entwurf.text,
      startsWith('Sehr geehrter Herr Müller,'),
    );
    await gebaut.cubit.close();
  });

  test('ein selbst geschriebener Text wird nicht mehr überschrieben', () async {
    // Sonst verlöre der Anwalt Getipptes, sobald er einen Empfänger ergänzt.
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    gebaut.cubit.setzeText('Mein eigener Text');
    gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

    expect(gebaut.cubit.state.entwurf.text, 'Mein eigener Text');
    await gebaut.cubit.close();
  });

  test('ein nachträglicher Anhang bringt den Bezugssatz mit', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);
    expect(gebaut.cubit.state.entwurf.text, isNot(contains('übersende')));

    gebaut.cubit.anhangHinzufuegen('C:/Akte/Anspruchsschreiben.pdf');

    expect(gebaut.cubit.state.entwurf.text, contains('übersende'));
    await gebaut.cubit.close();
  });

  test('dieselbe Adresse wird nicht zweimal aufgenommen', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    gebaut.cubit.empfaengerHinzufuegen('SCHADEN@huk.de');
    gebaut.cubit.kopieHinzufuegen('k.mueller@example.de');

    expect(gebaut.cubit.state.entwurf.an, hasLength(2));
    expect(gebaut.cubit.state.entwurf.kopie, isEmpty);
    await gebaut.cubit.close();
  });

  test('nach erfolgreichem Versand steht das Ergebnis bereit', () async {
    final repository = _FakeVersandRepository();
    final gebaut = baue(repository, mandanten: [mandant]);
    await gebaut.cubit.starte(
      vorgang: vorgang,
      anhangPfade: const ['C:/Akte/Brief.pdf'],
    );

    final erfolg = await gebaut.cubit.senden();

    expect(erfolg, isTrue);
    expect(gebaut.cubit.state.phase, EmailVersandPhase.gesendet);
    expect(gebaut.cubit.state.ergebnis?.empfaenger, hasLength(2));
    expect(repository.gesendet?.betreff, contains('84/26 C03'));
    expect(repository.absenderName, 'Rechtsanwalt Max Muster');
    await gebaut.cubit.close();
  });

  test('ein Fehler lässt den Entwurf vollständig stehen', () async {
    // Anhang noch in Word offen: Nach dem Schließen soll ein zweiter Klick
    // genügen — nichts Getipptes darf dabei verloren gehen.
    final gebaut = baue(
      _FakeVersandRepository(
        wirft: Exception('Der Anhang „Brief.pdf" lässt sich nicht lesen'),
      ),
      mandanten: [mandant],
    );
    await gebaut.cubit.starte(
      vorgang: vorgang,
      anhangPfade: const ['C:/Akte/Brief.pdf'],
    );
    final vorher = gebaut.cubit.state.entwurf;

    final erfolg = await gebaut.cubit.senden();

    expect(erfolg, isFalse);
    expect(gebaut.cubit.state.phase, EmailVersandPhase.verfassen);
    expect(gebaut.cubit.state.entwurf, vorher);
    expect(gebaut.cubit.state.fehler, contains('Brief.pdf'));
    expect(gebaut.cubit.state.fehler, isNot(contains('Exception')));
    await gebaut.cubit.close();
  });

  test('der Entwurf geht auch ohne Postfach-Zugang ans Mailprogramm', () async {
    // Genau dafür ist der zweite Weg die Rückfalltür (§4.7): Gesendet wird in
    // Outlook, die App braucht dafür keinen eigenen Zugang.
    final repository = _FakeVersandRepository(bereit: false);
    final gebaut = baue(repository, mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    expect(gebaut.cubit.state.kannSenden, isFalse);
    expect(gebaut.cubit.state.kannEntwurfOeffnen, isTrue);

    final ergebnis = await gebaut.cubit.entwurfOeffnen();

    expect(ergebnis?.inOutlook, isTrue);
    expect(repository.uebergeben, gebaut.cubit.state.entwurf);
    await gebaut.cubit.close();
  });

  test('nach dem Entwurf gilt der Vorgang nicht als versendet', () async {
    // Ob in Outlook tatsächlich gesendet wurde, weiß die App nicht — das
    // Häkchen im Abschlussdialog muss von Hand kommen (§4.8).
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    await gebaut.cubit.entwurfOeffnen();

    expect(gebaut.cubit.state.phase, EmailVersandPhase.verfassen);
    expect(gebaut.cubit.state.ergebnis, isNull);
    await gebaut.cubit.close();
  });

  test('ohne Outlook meldet der Entwurf den Dateiweg samt Grund', () async {
    final gebaut = baue(
      _FakeVersandRepository(entwurfWeg: 'datei'),
      mandanten: [mandant],
    );
    await gebaut.cubit.starte(vorgang: vorgang);

    final ergebnis = await gebaut.cubit.entwurfOeffnen();

    expect(ergebnis?.inOutlook, isFalse);
    expect(ergebnis?.hinweis, contains('Outlook'));
    await gebaut.cubit.close();
  });

  test('Anhaenge aus Outlook werden angeboten, nicht angehaengt', () async {
    // Was mitgeht, entscheidet der Anwalt -- wie bei den Dateien aus dem
    // Fall-Ordner (§4.7).
    final repository = _FakeVersandRepository()
      ..outlookAnhaenge = [r'C:\Outlook\Gutachten.pdf'];
    final gebaut = baue(repository, mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    final ergebnis = await gebaut.cubit.anhaengeAusOutlook();

    expect(ergebnis?.neu, 1);
    expect(ergebnis?.griff.pfade, hasLength(1));
    // Aus welcher Nachricht die Vorschlaege kommen, steht danach im Zustand --
    // ohne das laegen Dateien da, ohne dass etwas ihre Herkunft sagt.
    expect(gebaut.cubit.state.outlookQuelle?.betreff, 'AW: Unfall vom 12.03.');
    expect(gebaut.cubit.state.ausOutlook, [r'C:\Outlook\Gutachten.pdf']);
    expect(gebaut.cubit.state.entwurf.anhangPfade, isEmpty);
    await gebaut.cubit.close();
  });

  test('ein geholter Vorschlag laesst sich einzeln verwerfen', () async {
    // Wer aus der falschen Nachricht geholt hat, soll die Reihe wieder leer
    // bekommen, ohne den Dialog zu schliessen.
    final repository = _FakeVersandRepository()
      ..outlookAnhaenge = [r'C:\Outlook\Gutachten.pdf', r'C:\Outlook\Foto.jpg'];
    final gebaut = baue(repository, mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);
    await gebaut.cubit.anhaengeAusOutlook();

    gebaut.cubit.outlookAnhangVerwerfen(r'C:\Outlook\Foto.jpg');

    expect(gebaut.cubit.state.ausOutlook, [r'C:\Outlook\Gutachten.pdf']);
    // Was der Anwalt verwirft, soll nicht in der Ablage liegen bleiben.
    expect(repository.verworfen, [r'C:\Outlook\Foto.jpg']);
    await gebaut.cubit.close();
  });

  test('ein verworfener Vorschlag kommt beim erneuten Holen wieder', () async {
    // Der Rueckweg, wenn man sich verklickt hat: Die Datei liegt ja noch da.
    final repository = _FakeVersandRepository()
      ..outlookAnhaenge = [r'C:\Outlook\Gutachten.pdf'];
    final gebaut = baue(repository, mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);
    await gebaut.cubit.anhaengeAusOutlook();
    gebaut.cubit.outlookAnhangVerwerfen(r'C:\Outlook\Gutachten.pdf');

    await gebaut.cubit.anhaengeAusOutlook();

    expect(gebaut.cubit.state.ausOutlook, [r'C:\Outlook\Gutachten.pdf']);
    await gebaut.cubit.close();
  });

  test('dieselbe Datei wird nicht zweimal angeboten', () async {
    final repository = _FakeVersandRepository()
      ..outlookAnhaenge = [r'C:\Outlook\Gutachten.pdf'];
    final gebaut = baue(repository, mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    await gebaut.cubit.anhaengeAusOutlook();
    final zweiter = await gebaut.cubit.anhaengeAusOutlook();

    // Der Dienst legt je Nachricht denselben Pfad an, deshalb ist beim zweiten
    // Griff nichts neu -- und die Oberflaeche kann das sagen, statt still
    // nichts zu tun.
    expect(gebaut.cubit.state.ausOutlook, hasLength(1));
    expect(zweiter?.neu, 0);
    expect(zweiter?.griff.pfade, hasLength(1));
    await gebaut.cubit.close();
  });

  test('ohne offene Nachricht meldet Outlook null Anhaenge', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    final griff = await gebaut.cubit.anhaengeAusOutlook();

    expect(griff?.neu, 0);
    expect(griff?.griff.pfade, isEmpty);
    // Outlook hat geantwortet, es war nur nichts ausgewaehlt -- das ist etwas
    // anderes als ein stummes Outlook und wird auch anders gemeldet.
    expect(griff?.griff.outlookErreicht, isTrue);
    expect(griff?.griff.hatNachricht, isFalse);
    expect(gebaut.cubit.state.ausOutlook, isEmpty);
    expect(gebaut.cubit.state.holtAusOutlook, isFalse);
    await gebaut.cubit.close();
  });

  test('beim Oeffnen des Dialogs wird Outlook vorgewaermt', () async {
    // Der Kaltstart von Outlook dauert; er soll laufen, waehrend der Anwalt
    // tippt, nicht erst wenn er auf "In Outlook oeffnen" drueckt.
    final repository = _FakeVersandRepository();
    final gebaut = baue(repository, mandanten: [mandant]);

    await gebaut.cubit.starte(vorgang: vorgang);

    expect(repository.vorgewaermt, 1);
    await gebaut.cubit.close();
  });

  test('nach der Uebergabe an Outlook bleibt der Entwurf stehen', () async {
    // Der Dialog schliesst sich nicht mehr: Das Outlook-Fenster liegt
    // womoeglich hinter der App, und ein Dialog, der einfach verschwindet,
    // sieht aus wie ein verschluckter Klick.
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);
    final vorher = gebaut.cubit.state.entwurf;

    await gebaut.cubit.entwurfOeffnen();

    expect(gebaut.cubit.state.entwurfErgebnis?.inOutlook, isTrue);
    expect(gebaut.cubit.state.entwurf, vorher);
    expect(gebaut.cubit.state.kannEntwurfOeffnen, isTrue);
    await gebaut.cubit.close();
  });

  test('ein Anhang laesst sich fuer die Mail umbenennen', () async {
    // Umbenannt wird nur, was beim Empfaenger ankommt -- die Datei in der Akte
    // behaelt ihren Namen, deshalb bleibt der Pfad unveraendert.
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(
      vorgang: vorgang,
      anhangPfade: const [r'C:\Akte\IMG_2481.jpg'],
    );

    gebaut.cubit.anhangUmbenennen(r'C:\Akte\IMG_2481.jpg', 'Unfallfoto.jpg');

    expect(gebaut.cubit.state.entwurf.anhangPfade, [r'C:\Akte\IMG_2481.jpg']);
    expect(
      gebaut.cubit.state.entwurf.nameVon(r'C:\Akte\IMG_2481.jpg'),
      'Unfallfoto.jpg',
    );
    await gebaut.cubit.close();
  });

  test('ein leerer Name stellt den Dateinamen wieder her', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(
      vorgang: vorgang,
      anhangPfade: const [r'C:\Akte\IMG_2481.jpg'],
    );
    gebaut.cubit.anhangUmbenennen(r'C:\Akte\IMG_2481.jpg', 'Unfallfoto.jpg');

    gebaut.cubit.anhangUmbenennen(r'C:\Akte\IMG_2481.jpg', '  ');

    expect(
      gebaut.cubit.state.entwurf.nameVon(r'C:\Akte\IMG_2481.jpg'),
      'IMG_2481.jpg',
    );
    await gebaut.cubit.close();
  });

  test('ein entfernter Anhang nimmt seinen Namen mit', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(
      vorgang: vorgang,
      anhangPfade: const [r'C:\Akte\IMG_2481.jpg'],
    );
    gebaut.cubit.anhangUmbenennen(r'C:\Akte\IMG_2481.jpg', 'Unfallfoto.jpg');

    gebaut.cubit.anhangEntfernen(r'C:\Akte\IMG_2481.jpg');

    expect(gebaut.cubit.state.entwurf.anhangNamen, isEmpty);
    await gebaut.cubit.close();
  });

  group('gewählte Textvorlage (§4.7)', () {
    const vorlage = MailVorlage(
      id: 1,
      name: 'Anschreiben an den Mandanten',
      betreff:
          'Ihre Verkehrsunfallsache {{MandantName}} ./. {{VersichererName}}',
      text: '{{Anrede}},\n{{Zusatzgruß}},\n\nvielen Dank für Ihr Vertrauen.',
    );

    /// Eine Vorlage **ohne** Stelle für den Gruß — die gemeinsame Mail an
    /// Mandant und Versicherung.
    const ohneGrussStelle = MailVorlage(
      id: 2,
      name: 'Anspruchsschreiben an die Versicherung',
      betreff: 'Schadensache {{MandantName}}',
      text: '{{Anrede}},\n\nanbei das Anspruchsschreiben.',
    );

    final mitGruss = mandant.copyWith(
      persoenlicheGrussformel: 'Salamu aleikum',
    );

    test('ersetzt Betreff und Text und füllt die Platzhalter', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      gebaut.cubit.waehleVorlage(vorlage);

      final entwurf = gebaut.cubit.state.entwurf;
      expect(
        entwurf.betreff,
        'Ihre Verkehrsunfallsache Klaus Müller ./. HUK-COBURG',
      );
      expect(entwurf.text, startsWith('Sehr geehrte Damen und Herren,\n'));
      expect(gebaut.cubit.state.gewaehlteVorlage, vorlage);
      await gebaut.cubit.close();
    });

    test(
      'der Text bleibt abgeleitet, bis der Anwalt selbst schreibt',
      () async {
        // Die Vorlage ist keine einmalige Einfuegung, sondern eine Ableitung:
        // Anrede und Gruss haengen an den Empfaengern, also muss der Text ihnen
        // folgen. Erst getippter Text loest die Bindung — sonst verloere der
        // Anwalt beim naechsten Empfaenger, was er geschrieben hat.
        final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
        await gebaut.cubit.starte(vorgang: vorgang);

        gebaut.cubit.waehleVorlage(vorlage);
        expect(gebaut.cubit.state.textSelbstGeschrieben, isFalse);
        expect(
          gebaut.cubit.state.entwurf.text,
          startsWith('Sehr geehrte Damen und Herren,'),
        );

        gebaut.cubit.empfaengerEntfernen('schaden@huk.de');
        expect(
          gebaut.cubit.state.entwurf.text,
          startsWith('Sehr geehrter Herr Müller,'),
          reason: 'die Anrede folgt dem Empfaengerkreis weiter',
        );

        gebaut.cubit.setzeText('Von Hand geschrieben.');
        gebaut.cubit.empfaengerHinzufuegen('schaden@huk.de');

        expect(gebaut.cubit.state.textSelbstGeschrieben, isTrue);
        expect(gebaut.cubit.state.entwurf.text, 'Von Hand geschrieben.');
        await gebaut.cubit.close();
      },
    );

    test(
      'der Zusatzgruß geht mit, auch wenn die Gegenseite mitliest',
      () async {
        // Geaendert am 02.09.2026: Bis dahin sperrte der Empfaengerkreis ihn.
        // Die Vorlagenwahl ist die Entscheidung — hier steht der Platzhalter,
        // also geht der Gruss mit, und der Mitleser ist nur ein Hinweis.
        final gebaut = baue(_FakeVersandRepository(), mandanten: [mitGruss]);
        await gebaut.cubit.starte(vorgang: vorgang);

        // Vorbelegt stehen Mandant und Versicherung gemeinsam im Feld „An".
        gebaut.cubit.waehleVorlage(vorlage);
        expect(
          gebaut.cubit.state.zusatzgruss,
          'Salamu aleikum',
          reason: 'aus dem Mandanten vorbelegt',
        );
        expect(gebaut.cubit.state.grussMoeglich, isTrue);
        expect(gebaut.cubit.state.mitleserImAn, isTrue);
        expect(
          gebaut.cubit.state.entwurf.text,
          startsWith('Sehr geehrte Damen und Herren,\nSalamu aleikum,\n'),
          reason: 'die Anrede folgt den Empfaengern, der Gruss der Vorlage',
        );

        gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

        expect(gebaut.cubit.state.mitleserImAn, isFalse);
        expect(
          gebaut.cubit.state.entwurf.text,
          startsWith('Sehr geehrter Herr Müller,\nSalamu aleikum,\n'),
          reason:
              'der Text zieht nach, ohne dass die Vorlage neu gewaehlt wird',
        );
        await gebaut.cubit.close();
      },
    );

    test('ohne Platzhalter in der Vorlage ist die Wahl gesperrt', () async {
      // Sichtbar gesperrt statt still weggelassen: Die Chips haengen an
      // `grussMoeglich`, und das haengt allein an der Vorlage.
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mitGruss]);
      await gebaut.cubit.starte(vorgang: vorgang);

      expect(
        gebaut.cubit.state.grussMoeglich,
        isTrue,
        reason: 'ohne Vorlage gilt die Vorbelegung, und die hat eine Stelle',
      );

      gebaut.cubit.waehleVorlage(ohneGrussStelle);

      expect(gebaut.cubit.state.grussMoeglich, isFalse);
      expect(
        gebaut.cubit.state.zusatzgruss,
        'Salamu aleikum',
        reason: 'die Wahl bleibt stehen — sie gilt wieder nach dem Abwaehlen',
      );
      expect(
        gebaut.cubit.state.entwurf.text,
        isNot(contains('Salamu aleikum')),
        reason: 'die Vorlage hat keine Stelle dafuer',
      );
      await gebaut.cubit.close();
    });

    test('„keine Vorlage" führt zur Vorbelegung zurück', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      final vorbelegt = gebaut.cubit.state.entwurf.text;

      gebaut.cubit.waehleVorlage(vorlage);
      expect(gebaut.cubit.state.entwurf.text, isNot(vorbelegt));

      gebaut.cubit.waehleVorlage(null);

      expect(gebaut.cubit.state.gewaehlteVorlage, isNull);
      expect(gebaut.cubit.state.entwurf.text, vorbelegt);
      await gebaut.cubit.close();
    });

    test('und der Betreff geht mit zurück', () async {
      // Der behobene Fehler (03.09.2026): Zurück ging nur der Text. Der
      // Betreff der Vorlage blieb als ihr einziger Rest über einem Text
      // stehen, der schon wieder aus der Vorbelegung kam — und so ging die
      // Mail hinaus.
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      final vorbelegt = gebaut.cubit.state.entwurf.betreff;

      gebaut.cubit.waehleVorlage(vorlage);
      expect(gebaut.cubit.state.entwurf.betreff, isNot(vorbelegt));

      gebaut.cubit.waehleVorlage(null);

      expect(gebaut.cubit.state.entwurf.betreff, vorbelegt);
      await gebaut.cubit.close();
    });

    test('wer selbst getippt hat, behält seinen Betreff', () async {
      // Dieselbe Abwägung wie beim Vorgangswechsel: Handarbeit wird nicht
      // überschrieben.
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      gebaut.cubit.waehleVorlage(vorlage);
      gebaut.cubit.setzeText('Ganz eigener Text.');
      gebaut.cubit.setzeBetreff('Mein eigener Betreff');
      gebaut.cubit.waehleVorlage(null);

      expect(gebaut.cubit.state.entwurf.betreff, 'Mein eigener Betreff');
      await gebaut.cubit.close();
    });

    test(
      'ein gewählter Zusatzgruß steht ohne Vorlage unter der Anrede',
      () async {
        // Die Chips sollen auch dann wirken, wenn nur die Vorbelegung dasteht —
        // sonst waere der Gruss an eine Vorlage gebunden.
        final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
        await gebaut.cubit.starte(vorgang: vorgang);
        gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

        gebaut.cubit.setzeZusatzgruss('Sat Sri Akal');

        expect(
          gebaut.cubit.state.entwurf.text,
          startsWith('Sehr geehrter Herr Müller,\nSat Sri Akal,\n'),
        );

        gebaut.cubit.setzeZusatzgruss('');

        expect(
          gebaut.cubit.state.entwurf.text,
          startsWith('Sehr geehrter Herr Müller,\n\n'),
          reason: 'ohne Gruss bleibt keine Leerzeile stehen',
        );
        await gebaut.cubit.close();
      },
    );
  });

  group('ein Vorgang ohne Mandanten im Register (§4.7)', () {
    test('die gewählte Anredeart steht in der Zeile, auch ohne Nachnamen', () {
      // Der Bericht aus der Kanzlei (03.09.2026): „Mir gefaellt das Damen und
      // Herren nicht — wenn man Herr auswaehlt, soll auch Herr stehen." Ohne
      // Registermandanten zeigten alle Chips dieselbe Zeile, und ein Klick auf
      // die Anredeart bewegte nichts.
      final gebaut = baue(_FakeVersandRepository(), mandanten: const []);
      return gebaut.cubit.starte(vorgang: vorgang).then((_) {
        expect(gebaut.cubit.state.mandantBekannt, isFalse);
        expect(
          gebaut.cubit.state.entwurf.text,
          startsWith('Sehr geehrte Damen und Herren,'),
          reason: 'ohne Anredeart bleibt es dabei — geraten wird nicht',
        );

        gebaut.cubit.waehleGeschlecht(Anrede.herr);

        expect(
          gebaut.cubit.state.entwurf.text,
          startsWith('Sehr geehrter Herr,'),
        );
        expect(
          gebaut.cubit.anredeVorschau(sehrGeehrt),
          'Sehr geehrter Herr',
          reason: 'auf dem Chip steht, was in der Mail steht',
        );
        expect(
          gebaut.cubit.anredeNeutralGrund,
          isNull,
          reason: 'die Zeile ist nicht mehr neutral, also nichts zu erklaeren',
        );
        expect(
          gebaut.cubit.anredeartWirkung.anredezeile,
          isTrue,
          reason: 'und der Satz darueber sagt, dass sie jetzt wirkt',
        );
        return gebaut.cubit.close();
      });
    });

    test('„Keine Angabe" ist der Weg zurück zu Damen und Herren', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: const []);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.waehleGeschlecht(Anrede.frau);
      expect(gebaut.cubit.state.entwurf.text, startsWith('Sehr geehrte Frau,'));

      gebaut.cubit.waehleGeschlecht(Anrede.keine);

      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrte Damen und Herren,'),
      );
      await gebaut.cubit.close();
    });

    test('ein anderer Anfang wirkt ebenso', () async {
      const gutenTag = Anredebaustein(
        id: 2,
        maennlich: 'Guten Tag',
        weiblich: 'Guten Tag',
        neutral: 'Guten Tag',
      );
      final gebaut = baue(_FakeVersandRepository(), mandanten: const []);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.waehleGeschlecht(Anrede.herr);

      gebaut.cubit.waehleAnrede(gutenTag);

      expect(gebaut.cubit.state.entwurf.text, startsWith('Guten Tag Herr,'));
      await gebaut.cubit.close();
    });
  });

  group('der Dialog lädt noch (§4.7)', () {
    const vorlage = MailVorlage(
      id: 4,
      name: 'Kurz',
      betreff: 'Zu {{Referenz}}',
      text: '{{Anrede}},\n\nkurz und gut.',
    );

    test('ohne Erzeuger gibt es keinen Füller — statt eines Nullfehlers', () {
      // `PlatzhalterUebersicht` fragt im build danach, und zwar sobald eine
      // Vorlage gewaehlt ist. Bis zum 02.09.2026 stand hier `_ableitung!`:
      // Wer im Ladefenster eine Vorlage waehlte, bekam den Nullfehler mitten
      // im Aufbau des Dialogs.
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);

      gebaut.cubit.waehleVorlage(vorlage);

      expect(gebaut.cubit.fuellerFuer(const []), isNull);
      expect(gebaut.cubit.state.gewaehlteVorlage, vorlage);
      gebaut.cubit.close();
    });

    test(
      'eine im Ladefenster gewählte Vorlage wirkt, sobald er steht',
      () async {
        // Sonst blieb die Wahl wirkungslos, bis der Anwalt etwas anderes
        // anfasste: `_leiteAb` hatte sie verworfen, weil der Erzeuger fehlte.
        final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);

        final laeuft = gebaut.cubit.starte(vorgang: vorgang);
        gebaut.cubit.waehleVorlage(vorlage);
        await laeuft;

        expect(gebaut.cubit.state.entwurf.text, contains('kurz und gut.'));
        expect(
          gebaut.cubit.state.entwurf.betreff,
          contains('84/26 C03_GG-XY 123'),
        );
        expect(gebaut.cubit.fuellerFuer(const []), isNotNull);
        await gebaut.cubit.close();
      },
    );
  });

  group('gewählte Anrede (§4.7, §7.1)', () {
    const gutenTag = Anredebaustein(
      id: 2,
      maennlich: 'Guten Tag',
      weiblich: 'Guten Tag',
      neutral: 'Guten Tag',
    );

    test('der erste des Bestands gilt ohne Klick', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      expect(gebaut.cubit.state.anredebaustein, sehrGeehrt);
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrte Damen und Herren,'),
        reason: 'vorbelegt stehen Mandant und Versicherung gemeinsam im „An"',
      );
      await gebaut.cubit.close();
    });

    test('ohne Bestand bleibt die feste Briefanrede', () async {
      // Der Rueckfall ist der Punkt: Die Umstellung von „fest" auf „waehlbar"
      // darf keine Mail ohne Anrede hinterlassen.
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [mandant],
        anreden: const [],
      );
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

      expect(gebaut.cubit.state.anredebaustein, isNull);
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrter Herr Müller,'),
      );
      await gebaut.cubit.close();
    });

    test('ein anderer Anfang schreibt den Text neu', () async {
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [mandant],
        anreden: const [sehrGeehrt, gutenTag],
      );
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrter Herr Müller,'),
      );

      gebaut.cubit.waehleAnrede(gutenTag);

      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Guten Tag Herr Müller,'),
        reason: 'die Beugung folgt dem Mandanten, nicht dem Baustein',
      );
      await gebaut.cubit.close();
    });

    test('neutral ist vorausgewählt, sobald jemand mitliest', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      expect(gebaut.cubit.state.anredePersoenlichMoeglich, isFalse);
      expect(gebaut.cubit.state.anredeGehtNeutral, isTrue);

      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

      expect(gebaut.cubit.state.anredePersoenlichMoeglich, isTrue);
      expect(
        gebaut.cubit.state.anredeGehtNeutral,
        isFalse,
        reason: 'ohne eigene Wahl entscheidet der Empfaengerkreis',
      );
      await gebaut.cubit.close();
    });

    test('der Anwalt darf trotz Mitleser namentlich anreden', () async {
      // Hinweis statt Sperre (§4.7): Die App weist darauf hin und entscheidet
      // nicht.
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      gebaut.cubit.setzeAnredeNeutral(false);

      expect(gebaut.cubit.state.anredeGehtNeutral, isFalse);
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrter Herr Müller,'),
      );
      await gebaut.cubit.close();
    });

    test('null gibt die Entscheidung an den Empfängerkreis zurück', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.setzeAnredeNeutral(false);
      expect(gebaut.cubit.state.anredeGehtNeutral, isFalse);

      gebaut.cubit.setzeAnredeNeutral(null);

      expect(
        gebaut.cubit.state.anredeGehtNeutral,
        isTrue,
        reason: 'die Versicherung steht weiter im Feld „An"',
      );
      await gebaut.cubit.close();
    });

    test('die Vorschau zeigt, was auf dem Chip stehen soll', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

      expect(
        gebaut.cubit.anredeVorschau(gutenTag),
        'Guten Tag Herr Müller',
        reason: 'derselbe Weg wie der erzeugte Text',
      );
      await gebaut.cubit.close();
    });
  });

  group('gewählter Vorgang (§4.7)', () {
    final zweiterMandant = Mandant(
      id: 9,
      anrede: Anrede.frau,
      vorname: 'Petra',
      nachname: 'Schmitt',
      emailAdresse: 'p.schmitt@example.de',
      persoenlicheGrussformel: 'Sat Sri Akal',
      erstelltAm: DateTime(2026, 2, 1),
    );

    final zweiterVorgang = Vorgang(
      referenz: '85/26 C03_HG-E 1427',
      angefragtAm: DateTime(2026, 7, 1),
      laufendeNummer: 85,
      jahr: '26',
      abteilung: 'C03',
      mandantId: 9,
      mandantName: 'Petra Schmitt',
      gegner: 'Allianz',
    );

    test('ohne Vorgang steht kein Vorgang im Zustand', () async {
      final gebaut = baue(_FakeVersandRepository());
      await gebaut.cubit.starte();

      expect(gebaut.cubit.state.vorgang, isNull);
      expect(gebaut.cubit.state.entwurf.vorgangReferenz, isEmpty);
      await gebaut.cubit.close();
    });

    test('nachträglich gewählt belegt er Empfänger und Betreff', () async {
      // Der Fall aus dem Postfach: Die Antwort liess sich keinem Vorgang
      // zuordnen, der Anwalt traegt ihn im Dialog nach (§4.3).
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [mandant, zweiterMandant],
      );
      await gebaut.cubit.starte();
      expect(gebaut.cubit.state.entwurf.an, isEmpty);

      await gebaut.cubit.waehleVorgang(zweiterVorgang);

      expect(gebaut.cubit.state.vorgang, zweiterVorgang);
      expect(gebaut.cubit.state.entwurf.an, contains('p.schmitt@example.de'));
      expect(gebaut.cubit.state.entwurf.betreff, contains('Petra Schmitt'));
      expect(
        gebaut.cubit.state.entwurf.vorgangReferenz,
        '85/26 C03_HG-E 1427',
        reason: 'erst damit wird der Versand protokolliert',
      );
      expect(gebaut.cubit.state.wechseltVorgang, isFalse);
      await gebaut.cubit.close();
    });

    test('beim Wechsel bleibt, was der Anwalt eingetragen hat', () async {
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [mandant, zweiterMandant],
      );
      await gebaut.cubit.starte(
        vorgang: vorgang,
        anhangPfade: [r'C:\Akte\Anspruchsschreiben.pdf'],
      );
      gebaut.cubit.empfaengerHinzufuegen('sachbearbeiter@example.de');

      await gebaut.cubit.waehleVorgang(zweiterVorgang);

      final entwurf = gebaut.cubit.state.entwurf;
      expect(
        entwurf.an,
        contains('sachbearbeiter@example.de'),
        reason: 'getippte Adressen gehoeren dem Anwalt',
      );
      expect(
        entwurf.an,
        isNot(contains('k.mueller@example.de')),
        reason: 'die Vorbelegung des alten Vorgangs geht mit ihm',
      );
      expect(entwurf.anhangPfade, [
        r'C:\Akte\Anspruchsschreiben.pdf',
      ], reason: 'die Anhaenge haengen nicht am Vorgang');
      await gebaut.cubit.close();
    });

    test('der Zusatzgruß folgt dem neuen Mandanten', () async {
      // Ein Gruss, der fuer jemand anderen gedacht war, darf den Wechsel nicht
      // ueberleben (§5.1).
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [
          mandant.copyWith(persoenlicheGrussformel: 'Salamu aleikum'),
          zweiterMandant,
        ],
      );
      await gebaut.cubit.starte(vorgang: vorgang);
      expect(gebaut.cubit.state.zusatzgruss, 'Salamu aleikum');

      await gebaut.cubit.waehleVorgang(zweiterVorgang);

      expect(gebaut.cubit.state.zusatzgruss, 'Sat Sri Akal');
      await gebaut.cubit.close();
    });

    test('selbst geschriebener Text überlebt den Wechsel', () async {
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [mandant, zweiterMandant],
      );
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.setzeText('Von Hand geschrieben.');

      await gebaut.cubit.waehleVorgang(zweiterVorgang);

      expect(gebaut.cubit.state.entwurf.text, 'Von Hand geschrieben.');
      await gebaut.cubit.close();
    });

    test('„kein Vorgang" führt zum leeren Anschreiben zurück', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      await gebaut.cubit.waehleVorgang(null);

      expect(gebaut.cubit.state.vorgang, isNull);
      expect(gebaut.cubit.state.entwurf.vorgangReferenz, isEmpty);
      expect(
        gebaut.cubit.state.entwurf.an,
        isEmpty,
        reason: 'die Vorbelegung des alten Vorgangs geht mit ihm',
      );
      await gebaut.cubit.close();
    });

    test(
      'die Entscheidung „neutral anreden" überlebt den Wechsel nicht',
      () async {
        // Wie der Gruss und die Anredeart: Sie galt fuer **diesen**
        // Empfaengerkreis. Blieb sie stehen, wurde der naechste Mandant
        // namentlich angeredet, obwohl die Mail an die Versicherung ging.
        final gebaut = baue(
          _FakeVersandRepository(),
          mandanten: [mandant, zweiterMandant],
        );
        await gebaut.cubit.starte(vorgang: vorgang);
        gebaut.cubit.setzeAnredeNeutral(false);
        expect(gebaut.cubit.state.anredeNeutral, isFalse);

        await gebaut.cubit.waehleVorgang(zweiterVorgang);

        expect(
          gebaut.cubit.state.anredeNeutral,
          isNull,
          reason: 'null heisst wieder „wie der Empfaengerkreis es ergibt"',
        );
        await gebaut.cubit.close();
      },
    );

    test('wer in Kopie steht, zählt nach dem Wechsel mit', () async {
      // Der Wechsel rechnete die beiden Flags aus der `an`-Liste allein. Wer
      // in **Kopie** stand, fiel dabei heraus — die Flags widersprachen der
      // Anredezeile, die `EntwurfAbleitung` aus `alleEmpfaenger` baut.
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [mandant, zweiterMandant],
      );
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.kopieHinzufuegen('kanzlei@example.de');

      await gebaut.cubit.waehleVorgang(zweiterVorgang);

      expect(
        gebaut.cubit.state.entwurf.an,
        ['p.schmitt@example.de'],
        reason:
            'nur der neue Mandant — der zweite Vorgang schlaegt sonst nichts vor',
      );
      expect(gebaut.cubit.state.mitleserImAn, isTrue);
      expect(gebaut.cubit.state.anredePersoenlichMoeglich, isFalse);
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrte Damen und Herren,'),
        reason: 'Flags und Anredezeile muessen dasselbe sagen',
      );
      await gebaut.cubit.close();
    });

    test('eine getippte Adresse überlebt auch den zweiten Wechsel', () async {
      // Der Fall aus dem Postfach: zuerst tippen, dann den Vorgang zuordnen,
      // spaeter weiterwechseln. Zaehlte die Adresse ab der Zuordnung als
      // Vorbelegung — der Vorgang schlaegt sie ja auch vor —, verschwand sie
      // beim naechsten Wechsel doch noch.
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [mandant, zweiterMandant],
      );
      await gebaut.cubit.starte();
      gebaut.cubit.empfaengerHinzufuegen('k.mueller@example.de');

      await gebaut.cubit.waehleVorgang(vorgang);
      await gebaut.cubit.waehleVorgang(zweiterVorgang);

      expect(
        gebaut.cubit.state.entwurf.an,
        contains('k.mueller@example.de'),
        reason: 'getippt bleibt getippt, auch wenn ein Vorgang sie vorschlaegt',
      );
      expect(
        gebaut.cubit.state.entwurf.an,
        isNot(contains('schaden@huk.de')),
        reason: 'die echte Vorbelegung geht mit ihrem Vorgang',
      );
      await gebaut.cubit.close();
    });

    test('derselbe Vorgang noch einmal gewählt ändert nichts', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      final vorher = gebaut.cubit.state;

      await gebaut.cubit.waehleVorgang(vorgang);

      expect(gebaut.cubit.state, vorher);
      await gebaut.cubit.close();
    });
  });

  test('ein abgebrochener Dialog lässt starte() still auslaufen', () async {
    // „Abbrechen", bevor die Bereitschaft da ist: Navigator.pop schließt den
    // BlocProvider und damit den Cubit, während starte() noch wartet. Der
    // wartende emit lief davor in „Cannot emit new states after calling close"
    // — und weil starte() im create-Cascade ohne await gerufen wird, landete
    // das als unbehandelter Fehler.
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);

    final laeuft = gebaut.cubit.starte(vorgang: vorgang);
    await gebaut.cubit.close();

    await expectLater(laeuft, completes);
  });

  test('ein abgebrochener Dialog lässt senden() still auslaufen', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    final laeuft = gebaut.cubit.senden();
    await gebaut.cubit.close();

    // Die Mail ging hinaus — nur zu melden ist es niemandem mehr.
    await expectLater(laeuft, completion(isTrue));
  });

  group('gewählte Anredeart (§4.7)', () {
    /// Eine Vorlage, die beides braucht: die Anredezeile und zwei gebeugte
    /// Wörter im Text.
    const gebeugt = MailVorlage(
      id: 9,
      name: 'Gebeugt',
      betreff: 'Ansprüche {{unseres/unserer}} {{Mandant/Mandantin}}',
      text:
          '{{Anrede}},\n'
          '\n'
          '{{unser/unsere}} {{Mandant/Mandantin}} macht Ansprüche geltend.',
    );

    test('vorbelegt ist, was das Mandantenregister sagt (§5.1)', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      expect(gebaut.cubit.state.mandantAnrede, Anrede.herr);
      expect(
        gebaut.cubit.state.anredeGeschlecht,
        isNull,
        reason: 'gewählt ist zunächst nichts — die Vorgabe stimmt schon',
      );
      expect(gebaut.cubit.state.geschlecht, Anrede.herr);
      await gebaut.cubit.close();
    });

    test('der Satz sagt, worauf die Anredeart jetzt wirkt', () async {
      // Die drei Lagen einer echten Sitzung, in der Reihenfolge, in der sie
      // vorkommen: Mail an die Versicherung ohne Vorlage — dann mit einer
      // gebeugten Vorlage — dann nur noch an den Mandanten.
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      expect(
        gebaut.cubit.anredeartWirkung.wirkt,
        isFalse,
        reason: 'genau der Klick, der bisher wortlos nichts tat',
      );
      expect(gebaut.cubit.anredeartWirkung.hinweis, contains('nirgends'));

      gebaut.cubit.waehleVorlage(gebeugt);

      expect(gebaut.cubit.anredeartWirkung.woerter, 3);
      expect(gebaut.cubit.anredeartWirkung.anredezeile, isFalse);
      expect(
        gebaut.cubit.anredeartWirkung.hinweis,
        contains('die Anrede ist neutral'),
      );

      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

      expect(gebaut.cubit.anredeartWirkung.anredezeile, isTrue);
      expect(
        gebaut.cubit.anredeartWirkung.hinweis,
        'Wirkt auf die Anrede und auf 3 gebeugte Wörter in der Vorlage.',
      );
      await gebaut.cubit.close();
    });

    test(
      'eine Vorlage ohne {{Anrede}} nimmt der Anredeart die Zeile',
      () async {
        const ohneAnrede = MailVorlage(
          id: 10,
          name: 'Ohne Anrede',
          betreff: 'Ansprüche {{unseres/unserer}} {{Mandant/Mandantin}}',
          text: 'Hier fehlt die Anredezeile.',
        );
        final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
        await gebaut.cubit.starte(vorgang: vorgang);
        gebaut.cubit.empfaengerEntfernen('schaden@huk.de');
        gebaut.cubit.waehleVorlage(ohneAnrede);

        final wirkung = gebaut.cubit.anredeartWirkung;

        expect(wirkung.anredezeile, isFalse);
        expect(wirkung.ohneAnredezeile, isTrue);
        expect(
          wirkung.hinweis,
          isNot(contains('neutral')),
          reason: 'es gibt keine Anrede, die neutral sein könnte',
        );
        expect(AnredeChips.hinweisFuer(gebaut.cubit.state), isNotNull);
        await gebaut.cubit.close();
      },
    );

    test('die gewählte Art beugt den Vorlagentext', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.waehleVorlage(gebeugt);

      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      expect(
        gebaut.cubit.state.entwurf.text,
        contains('unsere Mandantin macht Ansprüche geltend.'),
      );
      expect(
        gebaut.cubit.state.entwurf.betreff,
        'Ansprüche unserer Mandantin',
        reason: 'die Wahl ist eine ausdrückliche Handlung — der Betreff auch',
      );
      await gebaut.cubit.close();
    });

    test('die Beugung im Text hängt nicht am Empfängerkreis', () async {
      // Der häufigste Fall: Mandant und Versicherung stehen gemeinsam im
      // Feld „An", die Anrede fällt darum neutral aus — und der Text spricht
      // trotzdem von „unserer Mandantin". Wären beide Angaben eine, ginge
      // genau diese Mail falsch hinaus.
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.waehleVorlage(gebeugt);

      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrte Damen und Herren,'),
      );
      expect(gebaut.cubit.state.entwurf.text, contains('unsere Mandantin'));
      await gebaut.cubit.close();
    });

    test('sie beugt auch die Anredezeile', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.waehleVorlage(gebeugt);
      gebaut.cubit.setzeAnredeNeutral(false);

      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrte Frau Müller,'),
        reason: 'ein Anfang, drei Formen — die Wahl entscheidet, welche gilt',
      );
      await gebaut.cubit.close();
    });

    test('„keine Angabe" setzt die errechnete neutrale Form', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.waehleVorlage(gebeugt);

      gebaut.cubit.waehleGeschlecht(Anrede.keine);

      expect(
        gebaut.cubit.state.entwurf.text,
        contains('unser(e) Mandant(in) macht'),
        reason:
            'gemeinsamer Wortstamm in Klammern (geändert am 02.09.2026 auf '
            'ausdrücklichen Auftrag)',
      );
      await gebaut.cubit.close();
    });

    test('eine gewählte Art macht die namentliche Anrede möglich', () async {
      // Am Register stand „keine Angabe" — dann war eine namentliche Anrede
      // unmöglich und der Umschalter „neutral" stand fest. Sagt der Anwalt
      // beim Verfassen, wen er anschreibt, muss beides nachziehen.
      final ohneAngabe = Mandant(
        id: 7,
        anrede: Anrede.keine,
        vorname: 'Klaus',
        nachname: 'Müller',
        emailAdresse: 'k.mueller@example.de',
        erstelltAm: DateTime(2026, 1, 1),
      );
      final gebaut = baue(_FakeVersandRepository(), mandanten: [ohneAngabe]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');
      expect(gebaut.cubit.state.anredePersoenlichMoeglich, isFalse);

      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      expect(gebaut.cubit.state.anredePersoenlichMoeglich, isTrue);
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrte Frau Müller,'),
      );
      await gebaut.cubit.close();
    });

    test('die Wahl gilt nur für diese Mail, das Register bleibt', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      expect(
        gebaut.cubit.state.mandantAnrede,
        Anrede.herr,
        reason:
            'in die Stammdaten wird nichts zurückgeschrieben (§1.3) — die '
            'Chipreihe zeigt daran, dass die Wahl abweicht',
      );
      await gebaut.cubit.close();
    });

    test('der Vorgangswechsel nimmt die Wahl mit dem Mandanten', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      await gebaut.cubit.waehleVorgang(null);

      expect(
        gebaut.cubit.state.anredeGeschlecht,
        isNull,
        reason:
            'sonst redet die nächste Mail jemand anderen in der Beugung des '
            'Vorgängers an — wie beim Zusatzgruß',
      );
      expect(gebaut.cubit.state.mandantAnrede, Anrede.keine);
      await gebaut.cubit.close();
    });
  });

  group('die Anredeart im Register nachtragen (§4.7, §5.1)', () {
    /// Ein Mandant ohne hinterlegte Anredeart — der Fall, den der Nachtrag
    /// behebt. Ohne ihn steht die Wahl bei jeder Mail an ihn wieder aus.
    final ohneAngabe = Mandant(
      id: 7,
      anrede: Anrede.keine,
      vorname: 'Klaus',
      nachname: 'Müller',
      emailAdresse: 'k.mueller@example.de',
      erstelltAm: DateTime(2026, 1, 1),
    );

    const gebeugt = MailVorlage(
      id: 9,
      name: 'Gebeugt',
      text: '{{unser/unsere}} {{Mandant/Mandantin}} macht Ansprüche geltend.',
    );

    test(
      'schreibt die Wahl ins Register und braucht sie danach nicht',
      () async {
        final gebaut = baue(_FakeVersandRepository(), mandanten: [ohneAngabe]);
        await gebaut.cubit.starte(vorgang: vorgang);
        gebaut.cubit.waehleGeschlecht(Anrede.frau);
        expect(gebaut.cubit.state.anredeartNachtragbar, isTrue);

        await gebaut.cubit.merkeAnredeart();

        expect(gebaut.schreiber.geschrieben?.anrede, Anrede.frau);
        expect(gebaut.cubit.state.mandantAnrede, Anrede.frau);
        expect(
          gebaut.cubit.state.anredeGeschlecht,
          isNull,
          reason:
              'es gibt nichts mehr zu übersteuern — und der Knopf verschwindet '
              'damit von selbst',
        );
        expect(gebaut.cubit.state.anredeartNachtragbar, isFalse);
        await gebaut.cubit.close();
      },
    );

    test(
      'der Erzeuger zieht nach, sonst beugt die nächste Ableitung falsch',
      () async {
        // Der Nachtrag setzt `anredeGeschlecht` auf null zurück. Ab da fragt die
        // Ableitung den Mandanten am Erzeuger — steht dort weiter „keine
        // Angabe", fällt der Text auf die neutrale Form zurück, obwohl im
        // Register nun „Frau" steht.
        final gebaut = baue(_FakeVersandRepository(), mandanten: [ohneAngabe]);
        await gebaut.cubit.starte(vorgang: vorgang);
        gebaut.cubit.waehleVorlage(gebeugt);
        gebaut.cubit.waehleGeschlecht(Anrede.frau);
        await gebaut.cubit.merkeAnredeart();

        gebaut.cubit.waehleVorlage(gebeugt);

        expect(
          gebaut.cubit.state.entwurf.text,
          contains('unsere Mandantin macht Ansprüche geltend.'),
        );
        await gebaut.cubit.close();
      },
    );

    test('eine hinterlegte Anredeart wird nicht überschrieben', () async {
      // `mandant` trägt „Herr". Eine Wahl „Frau" gilt für diese Mail — die
      // Stammdaten gehören ins Register, nicht in den Versanddialog (§1.3).
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      await gebaut.cubit.merkeAnredeart();

      expect(gebaut.schreiber.geschrieben, isNull);
      expect(gebaut.cubit.state.mandantAnrede, Anrede.herr);
      expect(gebaut.cubit.state.anredeGeschlecht, Anrede.frau);
      await gebaut.cubit.close();
    });

    test('misslingt das Schreiben, bleibt die Wahl für diese Mail', () async {
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [ohneAngabe],
        schreibenScheitert: true,
      );
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      await gebaut.cubit.merkeAnredeart();

      expect(gebaut.cubit.state.fehler, contains('nicht hinterlegen'));
      expect(
        gebaut.cubit.state.anredeGeschlecht,
        Anrede.frau,
        reason:
            'der Entwurf ist fertig — ein Registerfehler darf ihn nicht '
            'anfassen',
      );
      expect(gebaut.cubit.state.mandantAnrede, Anrede.keine);
      await gebaut.cubit.close();
    });

    test('ohne Mandanten am Vorgang gibt es nichts nachzutragen', () async {
      final gebaut = baue(_FakeVersandRepository());
      await gebaut.cubit.starte();
      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      expect(gebaut.cubit.state.mandantBekannt, isFalse);
      expect(gebaut.cubit.state.anredeartNachtragbar, isFalse);
      await gebaut.cubit.close();
    });
  });

  group('Chips im von Hand bearbeiteten Text (§4.7)', () {
    const gutenTag = Anredebaustein(
      id: 2,
      maennlich: 'Guten Tag',
      weiblich: 'Guten Tag',
      neutral: 'Guten Tag',
    );

    final mitGruss = Mandant(
      id: 7,
      anrede: Anrede.herr,
      vorname: 'Klaus',
      nachname: 'Müller',
      emailAdresse: 'k.mueller@example.de',
      persoenlicheGrussformel: 'Salamu aleikum',
      erstelltAm: DateTime(2026, 1, 1),
    );

    /// Ein Entwurf, in dem der Anwalt selbst geschrieben hat — der Zustand,
    /// in dem die Chips vorher still leer liefen.
    Future<({EmailEntwurfCubit cubit, _FakeUpdateMandant schreiber})>
    mitHandarbeit({Mandant? mandant}) async {
      final gebaut = baue(
        _FakeVersandRepository(),
        mandanten: [mandant ?? mitGruss],
      );
      await gebaut.cubit.starte(vorgang: vorgang);
      // Nur den Mandanten anschreiben, damit namentlich angeredet wird.
      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');
      gebaut.cubit.setzeAnredeNeutral(false);
      final vorher = gebaut.cubit.state.entwurf.text;
      gebaut.cubit.setzeText('$vorher\n\nUnd das habe ich selbst getippt.');
      return (cubit: gebaut.cubit, schreiber: gebaut.schreiber);
    }

    test('die Anredeart tauscht die Anredezeile, der Rest bleibt', () async {
      final gebaut = await mitHandarbeit();
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrter Herr Müller,'),
      );

      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrte Frau Müller,'),
      );
      expect(
        gebaut.cubit.state.entwurf.text,
        contains('Und das habe ich selbst getippt.'),
        reason: 'genau das darf der Klick nicht kosten',
      );
      await gebaut.cubit.close();
    });

    test('ein anderer Anredeanfang wirkt ebenso', () async {
      final gebaut = await mitHandarbeit();

      gebaut.cubit.waehleAnrede(gutenTag);

      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Guten Tag Herr Müller,'),
      );
      expect(
        gebaut.cubit.state.textSelbstGeschrieben,
        isTrue,
        reason: 'der Text bleibt Handarbeit — getauscht wurde nur eine Stelle',
      );
      await gebaut.cubit.close();
    });

    test('ein anderer Zusatzgruß wird an seiner Stelle getauscht', () async {
      final gebaut = await mitHandarbeit();
      expect(gebaut.cubit.state.entwurf.text, contains('Salamu aleikum,'));

      gebaut.cubit.setzeZusatzgruss('Grüß Gott');

      expect(gebaut.cubit.state.entwurf.text, contains('Grüß Gott,'));
      expect(gebaut.cubit.state.entwurf.text, isNot(contains('Salamu')));
      await gebaut.cubit.close();
    });

    test('kein Gruß mehr nimmt seine Zeile mit', () async {
      final gebaut = await mitHandarbeit();

      gebaut.cubit.setzeZusatzgruss('');

      expect(gebaut.cubit.state.entwurf.text, isNot(contains('Salamu')));
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrter Herr Müller,\n\n'),
        reason: 'sonst bliebe das Komma des Grusses allein auf seiner Zeile',
      );
      await gebaut.cubit.close();
    });

    test('eine andere Vorlage schreibt den Text nicht um', () async {
      final gebaut = await mitHandarbeit();
      final vorher = gebaut.cubit.state.entwurf.text;

      gebaut.cubit.waehleVorlage(
        const MailVorlage(id: 3, name: 'Andere', text: 'Ganz anderer Text.'),
      );

      expect(
        gebaut.cubit.state.entwurf.text,
        vorher,
        reason:
            'die Vorlage schreibt den **ganzen** Text — das waere der Verlust '
            'der Handarbeit, und dafuer gibt es erzeugeTextNeu',
      );
      await gebaut.cubit.close();
    });

    test('erzeugeTextNeu gibt den Text der Ableitung zurück', () async {
      final gebaut = await mitHandarbeit();
      gebaut.cubit.waehleVorlage(
        const MailVorlage(id: 3, name: 'Andere', text: 'Ganz anderer Text.'),
      );

      gebaut.cubit.erzeugeTextNeu();

      expect(gebaut.cubit.state.entwurf.text, 'Ganz anderer Text.');
      expect(gebaut.cubit.state.textSelbstGeschrieben, isFalse);
      await gebaut.cubit.close();
    });

    test('auch wer zuerst tippt, kann danach noch umschalten', () async {
      // Der Ablauf, in dem der Nachtrag tot war: **kein** Klick vorher.
      // `starte` schrieb die Merker nicht mit, `TextNachtrag` suchte nach der
      // leeren Zeichenkette und stieg sofort aus — der Chip tat nichts, und
      // der Hinweis daneben versprach das Gegenteil.
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mitGruss]);
      await gebaut.cubit.starte(vorgang: vorgang);
      final vorher = gebaut.cubit.state.entwurf.text;
      expect(vorher, startsWith('Sehr geehrte Damen und Herren,'));
      gebaut.cubit.setzeText('$vorher\n\nUnd das habe ich selbst getippt.');

      gebaut.cubit.setzeAnredeNeutral(false);

      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrter Herr Müller,'),
      );
      expect(
        gebaut.cubit.state.entwurf.text,
        contains('Und das habe ich selbst getippt.'),
      );
      await gebaut.cubit.close();
    });

    test('und den Zusatzgruß ebenso', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mitGruss]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.setzeText(
        '${gebaut.cubit.state.entwurf.text}\n\nSelbst getippt.',
      );

      gebaut.cubit.setzeZusatzgruss('Grüß Gott');

      expect(gebaut.cubit.state.entwurf.text, contains('Grüß Gott,'));
      expect(gebaut.cubit.state.entwurf.text, isNot(contains('Salamu')));
      await gebaut.cubit.close();
    });

    test('ein hinzugefügter Empfänger zieht den Merker mit', () async {
      // Zwischen Ableitung und Handarbeit: Der abgeleitete Text bekam eine
      // **neue** Anredezeile, der Merker blieb auf der alten stehen. Der
      // naechste Klick suchte danach und fand nichts.
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mitGruss]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrter Herr Müller,'),
      );

      gebaut.cubit.empfaengerHinzufuegen('schaden@huk.de');
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrte Damen und Herren,'),
      );
      gebaut.cubit.setzeText(
        '${gebaut.cubit.state.entwurf.text}\n\nSelbst getippt.',
      );

      gebaut.cubit.setzeAnredeNeutral(false);

      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrter Herr Müller,'),
      );
      expect(gebaut.cubit.state.entwurf.text, contains('Selbst getippt.'));
      await gebaut.cubit.close();
    });

    test('ohne Handarbeit tut erzeugeTextNeu nichts', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mitGruss]);
      await gebaut.cubit.starte(vorgang: vorgang);
      final vorher = gebaut.cubit.state;

      gebaut.cubit.erzeugeTextNeu();

      expect(gebaut.cubit.state, vorher);
      await gebaut.cubit.close();
    });
  });

  group('die neutrale Anrede erklärt sich (§4.7)', () {
    /// Ein Mandant, bei dem im Register keine Anredeart steht — der Fall, in
    /// dem „Sehr geehrte Damen und Herren" erschien, ohne dass jemand diese
    /// Anrede angelegt hatte.
    final ohneAnredeart = Mandant(
      id: 7,
      vorname: 'Klaus',
      nachname: 'Müller',
      emailAdresse: 'k.mueller@example.de',
      erstelltAm: DateTime(2026, 1, 1),
    );

    test('der Grund nennt den Mitleser und verschwindet mit ihm', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
      await gebaut.cubit.starte(vorgang: vorgang);

      expect(gebaut.cubit.anredeNeutralGrund, AnredeNeutralGrund.mitleser);

      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

      expect(
        gebaut.cubit.anredeNeutralGrund,
        isNull,
        reason:
            'jetzt ist die Anrede namentlich, und es gibt nichts zu '
            'erklären',
      );
      await gebaut.cubit.close();
    });

    test(
      'der Umschalter bleibt schaltbar, wenn die Gegenseite mitliest',
      () async {
        // Der Mangel: Angeboten wurde er nur, wenn die namentliche Anrede schon
        // galt — also nie bei der häufigsten Mail dieser Kanzlei.
        final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
        await gebaut.cubit.starte(vorgang: vorgang);

        expect(gebaut.cubit.state.anredePersoenlichMoeglich, isFalse);
        expect(gebaut.cubit.anredeGebeugtMachbar, isTrue);
        await gebaut.cubit.close();
      },
    );

    test('die Lücke im Register wird benannt und ist behebbar', () async {
      final gebaut = baue(_FakeVersandRepository(), mandanten: [ohneAnredeart]);
      await gebaut.cubit.starte(vorgang: vorgang);
      gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

      expect(
        gebaut.cubit.anredeNeutralGrund,
        AnredeNeutralGrund.keineAnredeart,
      );

      gebaut.cubit.waehleGeschlecht(Anrede.frau);

      expect(gebaut.cubit.anredeNeutralGrund, isNull);
      expect(
        gebaut.cubit.state.entwurf.text,
        startsWith('Sehr geehrte Frau Müller,'),
      );
      await gebaut.cubit.close();
    });

    test(
      'auch ohne Anredebestand folgt die Anrede der gewählten Art',
      () async {
        // Der behobene Fehler: Ohne Bestand lief die Zeile über
        // `Mandant.briefanrede` und las nur das Register — die Wahl für diese
        // Mail fiel unter den Tisch.
        final gebaut = baue(
          _FakeVersandRepository(),
          mandanten: [ohneAnredeart],
          anreden: const [],
        );
        await gebaut.cubit.starte(vorgang: vorgang);
        gebaut.cubit.empfaengerEntfernen('schaden@huk.de');

        expect(gebaut.cubit.state.anredebaustein, isNull);

        gebaut.cubit.waehleGeschlecht(Anrede.frau);

        expect(
          gebaut.cubit.state.entwurf.text,
          startsWith('Sehr geehrte Frau Müller,'),
        );
        await gebaut.cubit.close();
      },
    );
  });
}
