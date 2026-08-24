import 'dart:io';
import 'dart:typed_data';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:automation_app/features/word_automation/domain/usecases/convert_docx_to_pdf.dart';

/// Was beim Speichern an einen frei gewählten Ort herausgekommen ist: die
/// geschriebenen Dateien und — wenn etwas schiefging — die Meldung dazu.
/// Beides zusammen, weil bei „Word + PDF" das eine gelingen und das andere
/// scheitern kann; wer nur den Fehler zeigt, verschweigt die halbe Wahrheit.
typedef ExportErgebnis = ({List<String> gespeichert, String? fehler});

/// Schreibt die gewählten Fassungen des fertigen Schreibens nach
/// [zielOrdner], jeweils unter [basisname] mit der passenden Endung.
///
/// Anders als bei der Ablage in der Akte entsteht hier **keine** Datei neben
/// dem Original: das PDF wird direkt an den Zielort geschrieben. Ein
/// Speichern-Befehl soll nichts hinterlassen, wo der Anwalt es nicht erwartet
/// — nach der Ablage liegt die Word-Datei in der Akte, und dort hätte eine
/// stillschweigend danebengelegte PDF-Fassung nichts zu suchen.
Future<ExportErgebnis> speichereFassungen({
  required String wordPfad,
  required AblageFormat format,
  required String zielOrdner,
  required String basisname,
}) async {
  final gespeichert = <String>[];

  if (format.mitWord) {
    final ziel = zielpfad(zielOrdner, basisname, 'docx');
    try {
      await File(wordPfad).copy(ziel);
      gespeichert.add(ziel);
    } on FileSystemException catch (e) {
      return (
        gespeichert: gespeichert,
        fehler: 'Speichern fehlgeschlagen: ${e.message}',
      );
    }
  }

  if (!format.mitPdf) return (gespeichert: gespeichert, fehler: null);

  final ergebnis = await getIt<UseCase<Uint8List, ConvertDocxToPdfParams>>()(
    ConvertDocxToPdfParams(docxFilePath: wordPfad),
  );
  switch (ergebnis) {
    case Right(value: final bytes):
      final ziel = zielpfad(zielOrdner, basisname, 'pdf');
      try {
        await File(ziel).writeAsBytes(bytes, flush: true);
        gespeichert.add(ziel);
      } on FileSystemException catch (e) {
        return (
          gespeichert: gespeichert,
          fehler: 'PDF konnte nicht geschrieben werden: ${e.message}',
        );
      }
    case Left(value: final failure):
      return (
        gespeichert: gespeichert,
        fehler:
            'Die PDF-Fassung konnte nicht erstellt werden: '
            '${failure.message}',
      );
  }
  return (gespeichert: gespeichert, fehler: null);
}

String zielpfad(String ordner, String basisname, String endung) =>
    '$ordner${Platform.pathSeparator}$basisname.$endung';

/// Der Dateiname ohne Ordner und ohne Endung — die Grundlage für die beiden
/// Zieldateien. Funktioniert mit beiden Trennzeichen, weil Pfade hier mal vom
/// Dienst (Windows) und mal aus einem Test kommen.
String dateibasisname(String pfad) {
  final name = pfad.split(RegExp(r'[\\/]')).last;
  final punkt = name.lastIndexOf('.');
  return punkt <= 0 ? name : name.substring(0, punkt);
}

/// Der Ordneranteil eines Pfades, ohne abschließendes Trennzeichen. Leer,
/// wenn der Pfad keinen enthält.
String ordnerVon(String pfad) {
  final trenner = pfad.lastIndexOf(RegExp(r'[\\/]'));
  return trenner < 0 ? '' : pfad.substring(0, trenner);
}
