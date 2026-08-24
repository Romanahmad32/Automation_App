import 'dart:io';

import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:automation_app/features/word_automation/presentation/utils/dokument_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pfadbestandteile', () {
    test('dateibasisname liefert den Namen ohne Ordner und Endung', () {
      expect(
        dateibasisname(r'C:\App\Generated\Arbeit\84-26 C03\VORLAGE HGN.docx'),
        'VORLAGE HGN',
      );
      // Ein Punkt im Ordnernamen ist keine Endung, ein fehlender Punkt auch
      // nicht — beides kommt aus echten Kanzleiordnern.
      expect(dateibasisname(r'C:\Akten\Mustermann v. 2026\Brief'), 'Brief');
    });

    test('ordnerVon schneidet den Dateinamen ab', () {
      expect(
        ordnerVon(r'C:\Akten\Mustermann\Unfall\Brief.docx'),
        r'C:\Akten\Mustermann\Unfall',
      );
      expect(ordnerVon('Brief.docx'), '');
    });
  });

  test('speichert die Word-Fassung unter dem gewählten Namen', () async {
    final ordner = Directory.systemTemp.createTempSync('export_test');
    addTearDown(() => ordner.deleteSync(recursive: true));
    final quelle = File('${ordner.path}${Platform.pathSeparator}Original.docx')
      ..writeAsStringSync('Inhalt');

    final ergebnis = await speichereFassungen(
      wordPfad: quelle.path,
      format: AblageFormat.word,
      zielOrdner: ordner.path,
      basisname: 'Anspruchsschreiben',
    );

    expect(ergebnis.fehler, isNull);
    expect(ergebnis.gespeichert, [
      zielpfad(ordner.path, 'Anspruchsschreiben', 'docx'),
    ]);
    expect(File(ergebnis.gespeichert.single).readAsStringSync(), 'Inhalt');
  });

  test('meldet den Fehler, wenn die Quelldatei fehlt', () async {
    final ordner = Directory.systemTemp.createTempSync('export_test');
    addTearDown(() => ordner.deleteSync(recursive: true));

    final ergebnis = await speichereFassungen(
      wordPfad: '${ordner.path}${Platform.pathSeparator}Weg.docx',
      format: AblageFormat.word,
      zielOrdner: ordner.path,
      basisname: 'Kopie',
    );

    expect(ergebnis.gespeichert, isEmpty);
    expect(ergebnis.fehler, isNotNull);
  });
}
