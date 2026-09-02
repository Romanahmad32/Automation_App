import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kanzlei_settings_doubles.dart';

class MitschreibendesSpeichern
    implements UseCase<KanzleiSettings, KanzleiSettings> {
  KanzleiSettings? zuletzt;

  @override
  Future<Either<Failure, KanzleiSettings>> call(KanzleiSettings params) async {
    zuletzt = params;
    return Right(params);
  }
}

/// Liefert die Staende der Reihe nach — der erste beim Laden des Formulars,
/// der zweite beim Nachladen vor dem Schreiben. So sieht ein Test, was
/// passiert, wenn sich der Stand im Dienst zwischenzeitlich geaendert hat.
class WechselnderSettingsAbruf implements UseCase<KanzleiSettings, NoParams> {
  final List<KanzleiSettings> staende;
  int gelesen = 0;

  WechselnderSettingsAbruf(this.staende);

  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async {
    final stand = staende[gelesen.clamp(0, staende.length - 1)];
    gelesen++;
    return Right(stand);
  }
}

/// Laedt einmal und scheitert danach — fuer die Frage, was das Speichern tut,
/// wenn es den frischen Stand nicht bekommt.
class SpaeterScheiterndesLaden implements UseCase<KanzleiSettings, NoParams> {
  final KanzleiSettings stand;
  int gelesen = 0;

  SpaeterScheiterndesLaden(this.stand);

  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async {
    gelesen++;
    return gelesen == 1
        ? Right(stand)
        : Left(ServerFailure(message: 'Der Dienst antwortet nicht'));
  }
}

/// Die Signatur steht im E-Mail-Reiter, liegt aber im selben Einstellungssatz
/// wie die Kanzleidaten (§4.7). Sie darf deshalb weder die Nachbarfelder
/// überschreiben noch deren Bestätigungsmeldung auslösen.
void main() {
  const gespeichert = KanzleiSettings(
    name: 'Kanzlei Ahmad',
    abteilung: 'C03',
    laufendeAuftragsnummer: 84,
    mailSignatur: 'Alte Signatur',
  );

  late MitschreibendesSpeichern speichern;
  late KanzleiSettingsBloc bloc;

  setUp(() async {
    speichern = MitschreibendesSpeichern();
    bloc = KanzleiSettingsBloc(FesterSettingsAbruf(gespeichert), speichern);

    final geladen = bloc.stream.firstWhere((s) => s is KanzleiSettingsLoaded);
    bloc.add(const LoadKanzleiSettingsEvent());
    await geladen;
  });

  tearDown(() => bloc.close());

  Future<KanzleiSettingsLoaded> abwarten() async {
    return await bloc.stream.firstWhere((s) => s is KanzleiSettingsLoaded)
        as KanzleiSettingsLoaded;
  }

  test('speichert die Signatur und laesst die Kanzleidaten stehen', () async {
    final fertig = abwarten();
    bloc.add(const SaveMailSignaturEvent('Mit freundlichen Gruessen'));
    await fertig;

    expect(speichern.zuletzt?.mailSignatur, 'Mit freundlichen Gruessen');
    expect(speichern.zuletzt?.name, 'Kanzlei Ahmad');
    expect(speichern.zuletzt?.laufendeAuftragsnummer, 84);
  });

  test('meldet den Erfolg als Signatur, nicht als Kanzleidaten', () async {
    final fertig = abwarten();
    bloc.add(const SaveMailSignaturEvent('Neu'));

    expect((await fertig).gespeichert, KanzleiSettingsBereich.signatur);
  });

  test('ein Speichern der Kanzleidaten meldet sich als Kanzleidaten', () async {
    final fertig = abwarten();
    bloc.add(
      SaveKanzleiSettingsEvent(gespeichert.copyWith(name: 'Kanzlei Neu')),
    );

    expect((await fertig).gespeichert, KanzleiSettingsBereich.kanzlei);
  });

  group('die formatierte Signatur gehoert dem Dienst (§4.7)', () {
    const mitLogo = KanzleiSettings(
      name: 'Kanzlei Ahmad',
      abteilung: 'C03',
      laufendeAuftragsnummer: 84,
      mailSignatur: 'Aus Outlook',
      mailSignaturHtml: '<p>Kanzlei Ahmad · Logo</p>',
    );

    test(
      'das Speichern loescht die eben uebernommene HTML-Fassung nicht',
      () async {
        // Der Ablauf, der sie geloescht hat: Formular geladen (HTML leer), dann
        // „Aus Outlook uebernehmen" — der Dienst schreibt HTML und Bilder —,
        // dann „Speichern". Der Bloc kannte nur den alten Stand und schrieb ihn
        // mitsamt leerem HTML zurueck; unter jeder Mail stand danach nur noch
        // der Nur-Text.
        final abruf = WechselnderSettingsAbruf([gespeichert, mitLogo]);
        final schreiben = MitschreibendesSpeichern();
        final eigener = KanzleiSettingsBloc(abruf, schreiben);
        addTearDown(eigener.close);

        final geladen = eigener.stream.firstWhere(
          (s) => s is KanzleiSettingsLoaded,
        );
        eigener.add(const LoadKanzleiSettingsEvent());
        await geladen;

        final fertig = eigener.stream.firstWhere(
          (s) => s is KanzleiSettingsLoaded,
        );
        eigener.add(const SaveMailSignaturEvent('Von Hand nachgezogen'));
        await fertig;

        expect(
          schreiben.zuletzt?.mailSignaturHtml,
          '<p>Kanzlei Ahmad · Logo</p>',
        );
        expect(schreiben.zuletzt?.mailSignatur, 'Von Hand nachgezogen');
      },
    );

    test('auch das Speichern der Kanzleidaten laesst sie stehen', () async {
      // Derselbe Weg von der anderen Seite: Das Kanzleiformular kennt das Feld
      // nur so, wie es beim Laden war.
      final abruf = WechselnderSettingsAbruf([gespeichert, mitLogo]);
      final schreiben = MitschreibendesSpeichern();
      final eigener = KanzleiSettingsBloc(abruf, schreiben);
      addTearDown(eigener.close);

      // Erst laden — das ist der Stand, den das Formular zeigt; die Uebernahme
      // aus Outlook kommt danach und schreibt HTML in den Dienst.
      final geladen = eigener.stream.firstWhere(
        (s) => s is KanzleiSettingsLoaded,
      );
      eigener.add(const LoadKanzleiSettingsEvent());
      await geladen;

      final fertig = eigener.stream.firstWhere(
        (s) => s is KanzleiSettingsLoaded,
      );
      eigener.add(SaveKanzleiSettingsEvent(gespeichert.copyWith(name: 'Neu')));
      await fertig;

      expect(
        schreiben.zuletzt?.mailSignaturHtml,
        '<p>Kanzlei Ahmad · Logo</p>',
      );
      expect(schreiben.zuletzt?.name, 'Neu');
    });

    test(
      'ohne frischen Stand wird nicht geschrieben, sondern gemeldet',
      () async {
        // Blind zu speichern hiesse, die formatierte Signatur auf Verdacht zu
        // loeschen.
        final schreiben = MitschreibendesSpeichern();
        final eigener = KanzleiSettingsBloc(
          SpaeterScheiterndesLaden(gespeichert),
          schreiben,
        );
        addTearDown(eigener.close);

        final geladen = eigener.stream.firstWhere(
          (s) => s is KanzleiSettingsLoaded,
        );
        eigener.add(const LoadKanzleiSettingsEvent());
        await geladen;

        final gescheitert = eigener.stream.firstWhere(
          (s) => s is KanzleiSettingsError,
        );
        eigener.add(const SaveMailSignaturEvent('Geht nicht'));

        expect(
          (await gescheitert as KanzleiSettingsError).message,
          'Der Dienst antwortet nicht',
        );
        expect(schreiben.zuletzt, isNull);
      },
    );
  });

  test('ohne geladenen Stand wird nichts gespeichert', () async {
    final leer = KanzleiSettingsBloc(
      FesterSettingsAbruf(gespeichert),
      speichern,
    );
    addTearDown(leer.close);

    leer.add(const SaveMailSignaturEvent('Ins Leere'));
    await Future<void>.delayed(Duration.zero);

    expect(speichern.zuletzt, isNull);
  });
}
