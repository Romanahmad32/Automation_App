import 'dart:io';

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

/// Das Register im Speicher; merkt sich, was gespeichert wurde. Alles andere
/// an [MandantDatasource] braucht dieser Test nicht.
class MerkendeMandantDatasource implements MandantDatasource {
  final List<Mandant> mandanten;
  final List<Mandant> gespeichert = [];

  MerkendeMandantDatasource(this.mandanten);

  @override
  Future<List<Mandant>> loadMandanten() async => mandanten;

  @override
  Future<Mandant> updateMandant(Mandant mandant) async {
    gespeichert.add(mandant);
    return mandant;
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

    register = MerkendeMandantDatasource([
      mandant(1, 'Müller', ordner: ['VUnfallursache Müller']),
      mandant(2, 'Meier'),
    ]);
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
        aktenOrdnername: 'vunfallursache MÜLLER',
        unterordnerName: 'Unfall v. 01.01.2026',
        quelldateiPfade: [brief.path],
      ),
    );

    expect(ergebnis, isA<Left<Failure, Object>>());
    final meldung = (ergebnis as Left).value as Failure;
    expect(meldung.message, contains('gehört bereits Müller'));
    expect(stammordner.listSync(), isEmpty);
    expect(register.gespeichert, isEmpty);
  });

  test('die Ablage in den eigenen Ordner geht durch', () async {
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
  });

  test('Lösen nimmt den Ordner in jeder Schreibweise vom Mandanten', () async {
    final ergebnis = await repository.loeseOrdner(
      mandantId: 1,
      ordnername: 'VUNFALLURSACHE müller',
    );

    expect(ergebnis, isA<Right<Failure, Mandant>>());
    expect(register.gespeichert.single.aktenOrdnernamen, isEmpty);
  });
}
