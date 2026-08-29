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
