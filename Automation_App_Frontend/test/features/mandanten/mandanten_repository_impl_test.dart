import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/data/datasources/akten_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/arbeitspaket_datei_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/import_datei_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/import_paket_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/mandant_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/mandanten_import_datasource.dart';
import 'package:automation_app/features/mandanten/data/datasources/ordner_status_datasource.dart';
import 'package:automation_app/features/mandanten/data/repositories/mandanten_repository_impl.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mandanten_testaufbau.dart';

/// Antwortet auf `aktenordner/zuordnen` wie der Dienst: 409 als
/// [MandantException], wenn der Ordner einem anderen gehört — die Regel selbst
/// prüfen die Backend-Tests (`MandantenOrdnerZuordnungTests`). Merkt sich jeden
/// Aufruf. Alles andere an [MandantDatasource] braucht dieser Test nicht.
class MerkendeMandantDatasource implements MandantDatasource {
  /// Ordnername → ID des Mandanten, dem er gehört.
  final Map<String, int> inhaber;
  final List<({String ordnername, bool nurPruefen})> zuordnungen = [];

  MerkendeMandantDatasource(this.inhaber);

  @override
  Future<Mandant> ordneOrdnerZu({
    required int mandantId,
    required String ordnername,
    bool nurPruefen = false,
  }) async {
    zuordnungen.add((ordnername: ordnername, nurPruefen: nurPruefen));
    final besitzer = inhaber[ordnername];
    if (besitzer != null && besitzer != mandantId) {
      throw MandantException('Der Ordner „$ordnername" gehört bereits Müller.');
    }
    return mandant(mandantId, 'Meier', ordner: [ordnername]);
  }

  @override
  dynamic noSuchMethod(Invocation aufruf) => throw UnimplementedError(
    '${aufruf.memberName} wird hier nicht gebraucht',
  );
}

/// Die Datasources, die Ablage und Lösen nicht berühren.
class UngenutzteDatasources
    implements
        OrdnerStatusDatasource,
        ImportDateiDatasource,
        MandantenImportDatasource,
        ImportPaketDatasource,
        ArbeitspaketDateiDatasource {
  @override
  dynamic noSuchMethod(Invocation aufruf) => throw UnimplementedError(
    '${aufruf.memberName} wird hier nicht gebraucht',
  );
}

class FesterStammordner implements KanzleiSettingsRepository {
  final String stammordner;

  FesterStammordner(this.stammordner);

  @override
  Future<Either<Failure, KanzleiSettings>> getSettings() async =>
      Right(KanzleiSettings(aktenStammordner: stammordner));

  @override
  dynamic noSuchMethod(Invocation aufruf) => throw UnimplementedError(
    '${aufruf.memberName} wird hier nicht gebraucht',
  );
}

void main() {
  late Directory stammordner;
  late File brief;
  late MerkendeMandantDatasource register;
  late MandantenRepository repository;

  setUp(() {
    stammordner = Directory.systemTemp.createTempSync('akten_');
    addTearDown(() => stammordner.deleteSync(recursive: true));
    final arbeitsordner = Directory.systemTemp.createTempSync('arbeit_');
    addTearDown(() => arbeitsordner.deleteSync(recursive: true));
    brief = File('${arbeitsordner.path}/Anspruchsschreiben.docx')
      ..writeAsStringSync('Schreiben');

    register = MerkendeMandantDatasource({'VUnfallursache Müller': 1});
    final ungenutzt = UngenutzteDatasources();
    repository = MandantenRepositoryImpl(
      register,
      const FilesystemAktenDatasource(),
      ungenutzt,
      ungenutzt,
      ungenutzt,
      ungenutzt,
      ungenutzt,
      FesterStammordner(stammordner.path),
    );
  });

  // Das Backend lehnt den fremden Ordner ohnehin ab (409) — aber erst beim
  // Speichern der Zuordnung, und die kam bisher **nach** dem Kopieren. Dann
  // läge das Schreiben in der fremden Akte, und die App meldete einen Fehler.
  test('die Ablage in einen fremden Ordner schreibt nichts', () async {
    final ergebnis = await repository.legeDokumentAb(
      LegeDokumentAbParams(
        mandantId: 2,
        aktenOrdnername: 'VUnfallursache Müller',
        unterordnerName: 'Unfall v. 01.01.2026',
        quelldateiPfade: [brief.path],
      ),
    );

    expect(ergebnis, isA<Left<Failure, Object>>());
    final meldung = (ergebnis as Left).value as Failure;
    expect(meldung.message, contains('gehört bereits Müller'));
    expect(meldung.message, contains('Es wurde nichts abgelegt.'));
    expect(stammordner.listSync(), isEmpty);
    expect(register.zuordnungen, [
      (ordnername: 'VUnfallursache Müller', nurPruefen: true),
    ]);
  });

  // Erst prüfen, dann kopieren, dann zuordnen — ohne dafür das Register zu
  // holen (die Attrappe kennt `loadMandanten` gar nicht).
  test(
    'die Ablage in den eigenen Ordner prüft, kopiert und ordnet zu',
    () async {
      final ergebnis = await repository.legeDokumentAb(
        LegeDokumentAbParams(
          mandantId: 1,
          aktenOrdnername: 'VUnfallursache Müller',
          unterordnerName: 'Unfall v. 01.01.2026',
          quelldateiPfade: [brief.path],
        ),
      );

      expect(ergebnis, isA<Right<Failure, Object>>());
      expect(stammordner.listSync(), hasLength(1));
      expect(register.zuordnungen, [
        (ordnername: 'VUnfallursache Müller', nurPruefen: true),
        (ordnername: 'VUnfallursache Müller', nurPruefen: false),
      ]);
    },
  );
}
