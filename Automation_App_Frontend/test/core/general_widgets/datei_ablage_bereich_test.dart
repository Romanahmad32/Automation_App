import 'dart:io';

import 'package:automation_app/core/general_widgets/datei_ablage_bereich.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was beim Ziehen aus dem Explorer angenommen wird (§4.7). Windows reicht den
/// Pfad eines Ordners genauso durch wie den einer Datei — ungeprüft landete er
/// als Anhang in der Liste und fiele erst beim Senden auf.
void main() {
  late Directory arbeit;

  setUp(() {
    arbeit = Directory.systemTemp.createTempSync('ablage_test');
  });

  tearDown(() {
    if (arbeit.existsSync()) arbeit.deleteSync(recursive: true);
  });

  test('nimmt Dateien an und laesst Ordner liegen', () {
    final datei = File('${arbeit.path}${Platform.pathSeparator}Gutachten.pdf')
      ..writeAsStringSync('x');
    final ordner = Directory('${arbeit.path}${Platform.pathSeparator}Fotos')
      ..createSync();

    final angenommen = DateiAblageBereich.nurDateien([datei.path, ordner.path]);

    expect(angenommen, [datei.path]);
  });

  test('uebergeht leere Pfade und Dateien, die es nicht gibt', () {
    final angenommen = DateiAblageBereich.nurDateien([
      '',
      '${arbeit.path}${Platform.pathSeparator}gibt-es-nicht.pdf',
    ]);

    expect(angenommen, isEmpty);
  });

  test('behaelt die Reihenfolge, in der abgelegt wurde', () {
    final erst = File('${arbeit.path}${Platform.pathSeparator}a.pdf')
      ..writeAsStringSync('x');
    final dann = File('${arbeit.path}${Platform.pathSeparator}b.pdf')
      ..writeAsStringSync('x');

    expect(DateiAblageBereich.nurDateien([dann.path, erst.path]), [
      dann.path,
      erst.path,
    ]);
  });
}
