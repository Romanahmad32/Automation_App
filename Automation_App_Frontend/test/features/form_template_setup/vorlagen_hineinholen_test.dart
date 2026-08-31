import 'dart:io';

import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_hineinholen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Das Hineinholen (#33) entscheidet, ob eine gewählte Word-Datei schon im
/// Vorlagenordner liegt, und kopiert sie sonst hinein — ohne je eine
/// vorhandene Datei zu überschreiben.
void main() {
  test('liegtImOrdner fällt nicht auf den Namens-Präfix herein', () {
    expect(
      VorlagenHineinholen.liegtImOrdner(
        r'C:\Vorlagen',
        r'C:\VorlagenAlt\Anspruch.docx',
      ),
      isFalse,
    );
    expect(
      VorlagenHineinholen.liegtImOrdner(
        r'C:\Vorlagen',
        r'C:\vorlagen\Anspruch.docx',
      ),
      isTrue,
      reason: 'Windows-Pfade unterscheiden keine Groß-/Kleinschreibung',
    );
  });

  test('kopiere legt die Datei in den Ordner und überschreibt nie', () async {
    final dir = await Directory.systemTemp.createTemp('hineinholen-');
    addTearDown(() => dir.delete(recursive: true));
    final ordner = Directory('${dir.path}${Platform.pathSeparator}Vorlagen');
    await ordner.create();
    final quelle = File('${dir.path}${Platform.pathSeparator}Anspruch.docx');
    await quelle.writeAsString('von woanders');

    final neuerPfad = await VorlagenHineinholen.kopiere(
      ordner: ordner.path,
      quelle: quelle.path,
    );

    expect(neuerPfad, isNotNull);
    expect(await File(neuerPfad!).readAsString(), 'von woanders');
    expect(VorlagenHineinholen.liegtImOrdner(ordner.path, neuerPfad), isTrue);

    // Zweiter Versuch mit anderem Inhalt: die vorhandene Datei bleibt.
    await quelle.writeAsString('andere Fassung');
    final zweiter = await VorlagenHineinholen.kopiere(
      ordner: ordner.path,
      quelle: quelle.path,
    );
    expect(zweiter, isNull);
    expect(await File(neuerPfad).readAsString(), 'von woanders');
  });
}
