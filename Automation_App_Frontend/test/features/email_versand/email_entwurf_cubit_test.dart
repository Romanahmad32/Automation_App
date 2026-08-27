import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
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

  @override
  Future<List<String>> ladeOutlookAnhaenge() async {
    if (wirft != null) throw wirft!;
    return outlookAnhaenge;
  }

  @override
  Future<void> waermeEntwurfVor() async => vorgewaermt++;

  @override
  Future<List<OutlookSignatur>> ladeOutlookSignaturen() async => const [];

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

class _FakeVersichererRepository implements VersichererRepository {
  @override
  Future<List<Versicherer>> ladeVersicherer() async => const [];
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
    antwort: const ZentralrufReplyData(
      versichererName: 'HUK-COBURG',
      versichererEmail: 'schaden@huk.de',
    ),
  );

  ({EmailEntwurfCubit cubit, _FakeGetMandanten register}) baue(
    _FakeVersandRepository repository, {
    List<Mandant> mandanten = const [],
  }) {
    final register = _FakeGetMandanten(mandanten);
    return (
      cubit: EmailEntwurfCubit(
        repository,
        _FakeGetKanzleiSettings(),
        register,
        VersichererCubit(_FakeVersichererRepository()),
      ),
      register: register,
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
    expect(gebaut.cubit.state.kannSenden, isFalse);
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

    final anzahl = await gebaut.cubit.anhaengeAusOutlook();

    expect(anzahl, 1);
    expect(gebaut.cubit.state.ausOutlook, [r'C:\Outlook\Gutachten.pdf']);
    expect(gebaut.cubit.state.entwurf.anhangPfade, isEmpty);
    await gebaut.cubit.close();
  });

  test('dieselbe Datei wird nicht zweimal angeboten', () async {
    final repository = _FakeVersandRepository()
      ..outlookAnhaenge = [r'C:\Outlook\Gutachten.pdf'];
    final gebaut = baue(repository, mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    await gebaut.cubit.anhaengeAusOutlook();
    await gebaut.cubit.anhaengeAusOutlook();

    expect(gebaut.cubit.state.ausOutlook, hasLength(1));
    await gebaut.cubit.close();
  });

  test('ohne offene Nachricht meldet Outlook null Anhaenge', () async {
    final gebaut = baue(_FakeVersandRepository(), mandanten: [mandant]);
    await gebaut.cubit.starte(vorgang: vorgang);

    expect(await gebaut.cubit.anhaengeAusOutlook(), 0);
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
}
