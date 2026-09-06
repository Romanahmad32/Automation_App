import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:automation_app/features/mandanten/domain/services/ordner_pruefung.dart';
import 'package:flutter_test/flutter_test.dart';

/// Die Importdatei kommt von einem Programm, und ein Programm kann einen
/// Ordnernamen erfinden. Bis hierher wurde er klaglos gespeichert: der Ordner
/// war danach nie auffindbar, und die Zaehler des Zuordnungsstapels standen
/// still falsch. Die Pruefung findet genau diese Angaben — nicht mehr, damit
/// eine Maschine ohne Stammordner weiter importieren kann.
void main() {
  final vorhandene = OrdnernamenMenge([
    'VUnfallursache Mark',
    'Strafsache Anna Meier',
    'Buchhaltung 2024',
  ]);

  MandantenImportDatei datei(
    List<List<String>> zeilen, {
    List<String> ohneBezug = const [],
  }) => MandantenImportDatei(
    mandanten: [
      for (final ordner in zeilen)
        ImportMandantEintrag(aktenOrdnernamen: ordner),
    ],
    ohneMandantenbezug: ohneBezug,
  );

  group('OrdnerPruefung.unbekannteZeilen', () {
    test('meldet die Zeile, die einen unbekannten Ordner nennt', () {
      final zeilen = OrdnerPruefung.unbekannteZeilen(
        datei: datei([
          const ['VUnfallursache Mark'],
          const ['VUnfallursache Erfunden'],
        ]),
        vorhandene: vorhandene,
      );

      expect(zeilen, {1});
    });

    test('eine Zeile mit lauter bekannten Ordnern wird nicht gemeldet', () {
      final zeilen = OrdnerPruefung.unbekannteZeilen(
        datei: datei([
          const ['VUnfallursache Mark', 'Strafsache Anna Meier'],
        ]),
        vorhandene: vorhandene,
      );

      expect(zeilen, isEmpty);
    });

    // Windows kennt „VUnfallursache Mark" und „vunfallursache mark" als einen
    // Ordner. Genau verglichen meldete die Pruefung Zeilen, die der Import
    // gleich darauf zuordnet.
    test('die Schreibweise spielt keine Rolle', () {
      final zeilen = OrdnerPruefung.unbekannteZeilen(
        datei: datei([
          const ['vunfallursache mark'],
          const ['  STRAFSACHE ANNA MEIER  '],
        ]),
        vorhandene: vorhandene,
      );

      expect(zeilen, isEmpty);
    });

    test('eine Zeile ohne Ordnerangabe ist nie unbekannt', () {
      final zeilen = OrdnerPruefung.unbekannteZeilen(
        datei: datei([
          const [],
          const [''],
        ]),
        vorhandene: vorhandene,
      );

      expect(zeilen, isEmpty);
    });

    // Der Fall „kein Scan verfuegbar": kein Stammordner eingerichtet, das
    // Netzlaufwerk fehlt, oder die Datei wird auf einem anderen Arbeitsplatz
    // geprueft. Wuerde hier blockiert, waere der Import dort unbenutzbar.
    test('ohne gescannten Bestand wird nichts gemeldet', () {
      final leer = OrdnernamenMenge(const []);

      expect(
        OrdnerPruefung.unbekannteZeilen(
          datei: datei([
            const ['VUnfallursache Erfunden'],
          ]),
          vorhandene: leer,
        ),
        isEmpty,
      );
      expect(
        OrdnerPruefung.unbekannteOhneBezug(
          datei: datei(const [], ohneBezug: const ['Erfunden']),
          vorhandene: leer,
        ),
        isEmpty,
      );
      expect(OrdnerPruefung.istBekannt('Erfunden', leer), isTrue);
    });
  });

  group('OrdnerPruefung.unbekannteOhneBezug', () {
    // Ein Vermerk auf einen Ordner, den es nicht gibt, ist genauso wertlos wie
    // eine Zuordnung darauf — nur faellt er noch weniger auf, weil ihn keine
    // Mandantenkarte zeigt.
    test('prueft auch die Ordner ohne Mandantenbezug', () {
      final unbekannt = OrdnerPruefung.unbekannteOhneBezug(
        datei: datei(
          const [],
          ohneBezug: const ['buchhaltung 2024', 'Ablage 2019'],
        ),
        vorhandene: vorhandene,
      );

      expect(unbekannt, ['Ablage 2019']);
    });

    test('meldet den Namen in der Schreibweise der Datei', () {
      final unbekannt = OrdnerPruefung.unbekannteOhneBezug(
        datei: datei(const [], ohneBezug: const ['ABLAGE 2019']),
        vorhandene: vorhandene,
      );

      expect(unbekannt, ['ABLAGE 2019']);
    });
  });

  group('OrdnerPruefung.istBekannt', () {
    test('kennt den Bestand ohne Ruecksicht auf die Schreibweise', () {
      expect(
        OrdnerPruefung.istBekannt('vunfallursache mark', vorhandene),
        isTrue,
      );
      expect(
        OrdnerPruefung.istBekannt('VUnfallursache Marc', vorhandene),
        isFalse,
      );
    });
  });
}
