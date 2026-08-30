import 'dart:io';

import 'package:automation_app/core/general_classes/exceptions/custom_exceptions.dart';
import 'package:automation_app/features/mandanten/data/datasources/akten_datasource.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  const datasource = FilesystemAktenDatasource();

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

    // Der Scan liest die Fälle bewusst *nicht* mit: im Produktivbestand liegen
    // rund 4000 Akten-Ordner, und ein vollständiger Baumdurchlauf dauert auf
    // einem Netzlaufwerk Minuten. Was er liefert, ist der Ordner selbst samt
    // Änderungszeitpunkt — mehr braucht die Zuordnungsliste nicht.
    test('liest die Akten flach, ohne ihre Fälle', () async {
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
      expect(mark.faelle, isEmpty);
      expect(mark.faelleGeladen, isFalse);
      expect(mark.geaendertAm, isNotNull);
    });

    test('ignoriert Dateien direkt im Stammordner', () async {
      File('${tempDir.path}/lose_datei.txt').writeAsStringSync('x');
      Directory('${tempDir.path}/Akte A').createSync();

      final akten = await datasource.scanAkten(tempDir.path);

      expect(akten, hasLength(1));
      expect(akten.first.ordnername, 'Akte A');
    });
  });

  group('scanFaelle', () {
    test('liest Fälle und Dokumente einer Akte', () async {
      final akte = Directory('${tempDir.path}/VUnfallursache Mark')
        ..createSync();
      final fall = Directory('${akte.path}/Unfall v. 12.05.2019')..createSync();
      File('${fall.path}/Anspruchsschreiben.docx').writeAsStringSync('x');

      final faelle = await datasource.scanFaelle(akte.path);

      expect(faelle, hasLength(1));
      expect(faelle.first.name, 'Unfall v. 12.05.2019');
      expect(faelle.first.dokumente, hasLength(1));
      expect(faelle.first.dokumente.first, endsWith('Anspruchsschreiben.docx'));
    });

    // Verknüpft wird über den Ordnernamen, nicht über den Pfad: zwischen Scan
    // und Aufklappen kann der Ordner im Explorer umbenannt worden sein.
    test('nicht existierender Ordner liefert leere Liste', () async {
      expect(await datasource.scanFaelle('${tempDir.path}/weg'), isEmpty);
    });
  });

  group('legeDokumentAb', () {
    late File quelle;

    setUp(() async {
      quelle = File('${tempDir.path}/quelle.docx')..writeAsStringSync('inhalt');
    });

    test('legt in neuer Akte an und kopiert die Datei', () async {
      final ziel = (await datasource.legeDokumentAb(
        stammordner: tempDir.path,
        ordnername: 'Neumandant Müller',
        unterordnerName: 'Unfall v. 01.01.2026',
        quelldateiPfade: [quelle.path],
      )).zielpfade.single;

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

      final ziel = (await datasource.legeDokumentAb(
        stammordner: tempDir.path,
        ordnername: 'Bestandsakte',
        unterordnerName: 'Fall 2',
        quelldateiPfade: [quelle.path],
      )).zielpfade.single;

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
          quelldateiPfade: [quelle.path],
        ),
        throwsA(isA<MandantException>()),
      );
    });

    /// Der Kern: in der Akte steht die verbindliche Fassung. Ein stilles
    /// copy() daraufhin hiesse, ein abgelegtes Schreiben zu verlieren, ohne
    /// dass es jemand merkt.
    test(
      'meldet einen Konflikt, statt vorhandene Dateien zu ersetzen',
      () async {
        Future<AblageErgebnis> ablegen([AblageStrategie? strategie]) =>
            datasource.legeDokumentAb(
              stammordner: tempDir.path,
              ordnername: 'Akte',
              unterordnerName: 'Fall',
              quelldateiPfade: [quelle.path],
              strategie: strategie ?? AblageStrategie.fragen,
            );

        final erste = await ablegen();
        quelle.writeAsStringSync('neuer inhalt');
        final zweite = await ablegen();

        expect(zweite.konflikt, isTrue);
        expect(zweite.konfliktPfade, erste.zielpfade);
        expect(zweite.zielpfade, isEmpty);
        expect(File(erste.zielpfade.single).readAsStringSync(), 'inhalt');
      },
    );

    test('ersetzt auf ausdrueckliche Ansage', () async {
      Future<AblageErgebnis> ablegen(AblageStrategie strategie) =>
          datasource.legeDokumentAb(
            stammordner: tempDir.path,
            ordnername: 'Akte',
            unterordnerName: 'Fall',
            quelldateiPfade: [quelle.path],
            strategie: strategie,
          );

      final erste = await ablegen(AblageStrategie.fragen);
      quelle.writeAsStringSync('neuer inhalt');
      final zweite = await ablegen(AblageStrategie.ersetzen);

      expect(zweite.konflikt, isFalse);
      expect(zweite.zielpfade, erste.zielpfade);
      expect(File(zweite.zielpfade.single).readAsStringSync(), 'neuer inhalt');
    });

    test('behaelt auf Wunsch beide Fassungen nebeneinander', () async {
      Future<AblageErgebnis> ablegen(AblageStrategie strategie) =>
          datasource.legeDokumentAb(
            stammordner: tempDir.path,
            ordnername: 'Akte',
            unterordnerName: 'Fall',
            quelldateiPfade: [quelle.path],
            strategie: strategie,
          );

      final erste = await ablegen(AblageStrategie.fragen);
      quelle.writeAsStringSync('neuer inhalt');
      final zweite = await ablegen(AblageStrategie.beideBehalten);

      expect(zweite.zielpfade.single, endsWith('quelle (2).docx'));
      expect(File(erste.zielpfade.single).readAsStringSync(), 'inhalt');
      expect(File(zweite.zielpfade.single).readAsStringSync(), 'neuer inhalt');
    });

    /// Word-Fassung und PDF sind ein Schreiben. Einzeln entschieden hiesse die
    /// eine „Brief (2).docx" und das andere „Brief.pdf" — niemand saehe ihnen
    /// noch an, dass sie zusammengehoeren.
    test('nummeriert beide Fassungen gemeinsam', () async {
      final pdf = File('${tempDir.path}/quelle.pdf')
        ..writeAsStringSync('pdf-inhalt');
      Future<AblageErgebnis> ablegen(AblageStrategie strategie) =>
          datasource.legeDokumentAb(
            stammordner: tempDir.path,
            ordnername: 'Akte',
            unterordnerName: 'Fall',
            quelldateiPfade: [quelle.path, pdf.path],
            strategie: strategie,
          );

      await ablegen(AblageStrategie.fragen);
      final zweite = await ablegen(AblageStrategie.beideBehalten);

      expect(zweite.zielpfade, hasLength(2));
      expect(zweite.zielpfade[0], endsWith('quelle (2).docx'));
      expect(zweite.zielpfade[1], endsWith('quelle (2).pdf'));
    });

    /// Auch wenn nur eine der beiden Fassungen schon dort liegt, wird einmal
    /// gefragt — und die Nummer gilt danach fuer beide.
    test('fragt einmal, wenn nur eine Fassung vorhanden ist', () async {
      final pdf = File('${tempDir.path}/quelle.pdf')
        ..writeAsStringSync('pdf-inhalt');
      await datasource.legeDokumentAb(
        stammordner: tempDir.path,
        ordnername: 'Akte',
        unterordnerName: 'Fall',
        quelldateiPfade: [quelle.path],
      );

      final beide = await datasource.legeDokumentAb(
        stammordner: tempDir.path,
        ordnername: 'Akte',
        unterordnerName: 'Fall',
        quelldateiPfade: [quelle.path, pdf.path],
      );

      expect(beide.konfliktPfade, hasLength(1));
      expect(beide.konfliktPfade.single, endsWith('quelle.docx'));
      // Nichts geschrieben: auch das PDF wartet auf die Entscheidung.
      expect(
        File('${tempDir.path}/Akte/Fall/quelle.pdf').existsSync(),
        isFalse,
      );

      final geloest = await datasource.legeDokumentAb(
        stammordner: tempDir.path,
        ordnername: 'Akte',
        unterordnerName: 'Fall',
        quelldateiPfade: [quelle.path, pdf.path],
        strategie: AblageStrategie.beideBehalten,
      );

      expect(geloest.zielpfade[0], endsWith('quelle (2).docx'));
      expect(geloest.zielpfade[1], endsWith('quelle (2).pdf'));
    });

    test('legt eine bereits abgelegte Datei nicht auf sich selbst', () async {
      final erste = await datasource.legeDokumentAb(
        stammordner: tempDir.path,
        ordnername: 'Akte',
        unterordnerName: 'Fall',
        quelldateiPfade: [quelle.path],
      );

      // Nach der Ablage arbeitet der Wizard mit der Kopie in der Akte weiter —
      // „Erneut ablegen" zeigt dann auf denselben Pfad.
      final zweite = await datasource.legeDokumentAb(
        stammordner: tempDir.path,
        ordnername: 'Akte',
        unterordnerName: 'Fall',
        quelldateiPfade: [erste.zielpfade.single],
      );

      expect(zweite.konflikt, isFalse);
      expect(zweite.zielpfade, erste.zielpfade);
      expect(File(zweite.zielpfade.single).readAsStringSync(), 'inhalt');
    });

    test('wirft bei fehlender Quelldatei', () async {
      expect(
        () => datasource.legeDokumentAb(
          stammordner: tempDir.path,
          ordnername: 'X',
          unterordnerName: 'Y',
          quelldateiPfade: ['${tempDir.path}/nicht_da.docx'],
        ),
        throwsA(isA<MandantException>()),
      );
    });
  });
}
