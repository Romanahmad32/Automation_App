import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/mandanten/data/datasources/akten_filesystem_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  const datasource = AktenFilesystemDatasource();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('akten_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('scanAkten', () {
    test('leerer Pfad liefert leere Liste', () async {
      expect(await datasource.scanAkten(''), isEmpty);
    });

    test('nicht existierender Pfad liefert leere Liste', () async {
      expect(
        await datasource.scanAkten('${tempDir.path}/gibt_es_nicht'),
        isEmpty,
      );
    });

    test('liest Akten, Fälle und Dokumente', () async {
      final akte = Directory('${tempDir.path}/VUnfallursache Mark')
        ..createSync();
      final fall = Directory('${akte.path}/Unfall v. 12.05.2019')..createSync();
      File('${fall.path}/Anspruchsschreiben.docx').writeAsStringSync('x');
      Directory('${tempDir.path}/Strafsache Saeed').createSync();

      final akten = await datasource.scanAkten(tempDir.path);

      expect(akten, hasLength(2));
      // alphabetisch sortiert: Strafsache vor VUnfallursache
      expect(akten.first.ordnername, 'Strafsache Saeed');
      final mark = akten.firstWhere(
        (a) => a.ordnername == 'VUnfallursache Mark',
      );
      expect(mark.faelle, hasLength(1));
      expect(mark.faelle.first.name, 'Unfall v. 12.05.2019');
      expect(mark.faelle.first.dokumente, hasLength(1));
      expect(
        mark.faelle.first.dokumente.first,
        endsWith('Anspruchsschreiben.docx'),
      );
    });

    test('ignoriert Dateien direkt im Stammordner', () async {
      File('${tempDir.path}/lose_datei.txt').writeAsStringSync('x');
      Directory('${tempDir.path}/Akte A').createSync();

      final akten = await datasource.scanAkten(tempDir.path);

      expect(akten, hasLength(1));
      expect(akten.first.ordnername, 'Akte A');
    });
  });

  group('legeDokumentAb', () {
    late File quelle;

    setUp(() async {
      quelle = File('${tempDir.path}/quelle.docx')..writeAsStringSync('inhalt');
    });

    test('legt in neuer Akte an und kopiert die Datei', () async {
      final ziel = await datasource.legeDokumentAb(
        stammordner: tempDir.path,
        ordnername: 'Neumandant Müller',
        unterordnerName: 'Unfall v. 01.01.2026',
        quelldateiPfad: quelle.path,
      );

      expect(File(ziel).existsSync(), isTrue);
      expect(ziel, endsWith('quelle.docx'));
      expect(
        Directory(
          '${tempDir.path}/Neumandant Müller/Unfall v. 01.01.2026',
        ).existsSync(),
        isTrue,
      );
      expect(File(ziel).readAsStringSync(), 'inhalt');
    });

    test('nutzt vorhandene Akte und legt nur Unterordner an', () async {
      Directory('${tempDir.path}/Bestandsakte').createSync();

      final ziel = await datasource.legeDokumentAb(
        stammordner: tempDir.path,
        ordnername: 'Bestandsakte',
        unterordnerName: 'Fall 2',
        quelldateiPfad: quelle.path,
      );

      expect(File(ziel).existsSync(), isTrue);
      // Es darf keine zweite Akte „Bestandsakte" entstehen.
      final akten = await datasource.scanAkten(tempDir.path);
      expect(akten.where((a) => a.ordnername == 'Bestandsakte'), hasLength(1));
    });

    test('wirft bei leerem Stammordner', () async {
      expect(
        () => datasource.legeDokumentAb(
          stammordner: '',
          ordnername: 'X',
          unterordnerName: 'Y',
          quelldateiPfad: quelle.path,
        ),
        throwsA(isA<MandantException>()),
      );
    });

    test('wirft bei fehlender Quelldatei', () async {
      expect(
        () => datasource.legeDokumentAb(
          stammordner: tempDir.path,
          ordnername: 'X',
          unterordnerName: 'Y',
          quelldateiPfad: '${tempDir.path}/nicht_da.docx',
        ),
        throwsA(isA<MandantException>()),
      );
    });
  });
}
