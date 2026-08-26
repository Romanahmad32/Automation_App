import 'dart:io';

import 'package:automation_app/features/word_automation/presentation/utils/mail_anhaenge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Was von selbst an der Mail hängt und was nur angeboten wird (§4.7).
/// Nach außen geht die PDF-Fassung — die Word-Datei ist die Arbeitsfassung.
void main() {
  late Directory fallOrdner;

  setUp(() {
    fallOrdner = Directory.systemTemp.createTempSync('mail_anhaenge_test');
  });

  tearDown(() {
    if (fallOrdner.existsSync()) fallOrdner.deleteSync(recursive: true);
  });

  String lege(String name) {
    final datei = File('${fallOrdner.path}${Platform.pathSeparator}$name')
      ..writeAsStringSync('Inhalt');
    return datei.path;
  }

  test('wählt die PDF-Fassung vor, nicht die Word-Datei', () {
    final docx = lege('Anspruchsschreiben.docx');
    final pdf = lege('Anspruchsschreiben.pdf');

    final anhaenge = MailAnhangAuswahl.zu(docx);

    expect(anhaenge.vorauswahl, [pdf]);
    expect(anhaenge.ausDerAkte, [docx]);
  });

  test('bietet die übrigen Dateien des Fall-Ordners an', () {
    final pdf = lege('Anspruchsschreiben.pdf');
    final gutachten = lege('Gutachten.pdf');
    final foto = lege('Foto.jpg');

    final anhaenge = MailAnhangAuswahl.zu(pdf);

    expect(anhaenge.vorauswahl, [pdf]);
    expect(anhaenge.ausDerAkte, containsAll([gutachten, foto]));
    expect(anhaenge.ausDerAkte, isNot(contains(pdf)));
  });

  test('ohne PDF hängt die vorhandene Fassung dran', () {
    // Ablage „nur Word": Irgendetwas anzuhängen ist besser als nichts.
    final docx = lege('Anspruchsschreiben.docx');

    expect(MailAnhangAuswahl.zu(docx).vorauswahl, [docx]);
  });

  test('übergeht die Sperrdateien eines geöffneten Word-Dokuments', () {
    final docx = lege('Anspruchsschreiben.docx');
    lege(r'~$spruchsschreiben.docx');

    expect(MailAnhangAuswahl.zu(docx).ausDerAkte, isEmpty);
  });

  test('ohne abgelegtes Dokument bleibt alles leer', () {
    final leer = MailAnhangAuswahl.zu(null);

    expect(leer.vorauswahl, isEmpty);
    expect(leer.ausDerAkte, isEmpty);
  });
}
