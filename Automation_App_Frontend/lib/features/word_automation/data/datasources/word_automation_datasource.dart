import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:automation_app/core/network/backend_fehlertext.dart';
import 'package:automation_app/features/word_automation/domain/entities/arbeitsordner_aufraeumung.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/entities/rvg_calculation.dart';
import 'package:automation_app/features/word_automation/domain/entities/vorlagen_uebersicht.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class WordAutomationDatasource {
  Future<GeneratedDocument> fillOutTemplate(
    String path,
    Map<String, String> values, {
    DamageListing? damageListing,
    bool? vorsteuerabzugsberechtigt,
    String? outputFileName,
    String? vorgangSchluessel,
  });

  Future<ArbeitsordnerAufraeumung> arbeitsordnerAufraeumen(
    String vorgangSchluessel,
  );

  Future<Uint8List> convertDocxToPdf(String docxFilePath);

  Future<VorlagenUebersicht> getVorlagenUebersicht();

  Future<RvgCalculation> calculateRvgFees(
    double gegenstandswert,
    double gebuehrensatz,
    bool applyVat, {
    double? geschaeftsgebuehrOverride,
    double? auslagenpauschaleOverride,
  });
}

@Injectable(as: WordAutomationDatasource)
class ApiWordAutomationDatasource implements WordAutomationDatasource {
  final Dio _dio;

  ApiWordAutomationDatasource(this._dio);

  @override
  Future<VorlagenUebersicht> getVorlagenUebersicht() async {
    final response = await _dio.get('/api/WordAutomation/vorlagen');
    final data = response.data as Map<String, dynamic>;
    return VorlagenUebersicht(
      verzeichnis: data['verzeichnis'] as String,
      vorlagen: [
        for (final eintrag in (data['vorlagen'] as List? ?? const []))
          Vorlage(
            name: (eintrag as Map<String, dynamic>)['name'] as String,
            pfad: eintrag['pfad'] as String,
            geaendertAm: DateTime.parse(eintrag['geaendertAm'] as String),
          ),
      ],
    );
  }

  @override
  Future<GeneratedDocument> fillOutTemplate(
    String path,
    Map<String, String> values, {
    DamageListing? damageListing,
    bool? vorsteuerabzugsberechtigt,
    String? outputFileName,
    String? vorgangSchluessel,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post(
        '/api/WordAutomation/replaced-document',
        data: {
          'TemplateFilePath': path,
          'replacePatterns': values,
          if (outputFileName != null && outputFileName.trim().isNotEmpty)
            'OutputFileName': outputFileName.trim(),
          // Bestimmt den Arbeitsordner: je Vorgang einer, damit eine Neuerzeugung
          // die vorige Fassung ersetzt, ohne einem anderen Vorgang dazwischenzugehen.
          if (vorgangSchluessel != null && vorgangSchluessel.trim().isNotEmpty)
            'VorgangSchluessel': vorgangSchluessel.trim(),
          'vorsteuerabzugsberechtigt': ?vorsteuerabzugsberechtigt,
          if (damageListing != null) 'damageListing': damageListing.toJson(),
        },
        options: Options(
          contentType: Headers.jsonContentType,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      stopwatch.stop();
      developer.log(
        'Backend-Erzeugung (Dio POST): ${stopwatch.elapsedMilliseconds} ms',
        name: 'PERF',
      );

      final responseData = response.data as Map<String, dynamic>;
      return GeneratedDocument(
        outputFilePath: responseData['outputFilePath'] as String,
        warnings:
            (responseData['warnings'] as List?)?.cast<String>() ?? const [],
      );
    } on DioException catch (e) {
      stopwatch.stop();
      developer.log(
        'Backend-Erzeugung FEHLGESCHLAGEN nach ${stopwatch.elapsedMilliseconds} ms',
        name: 'PERF',
      );
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(e, 'Das Schreiben konnte nicht erzeugt werden'),
      );
    }
  }

  @override
  Future<ArbeitsordnerAufraeumung> arbeitsordnerAufraeumen(
    String vorgangSchluessel,
  ) async {
    try {
      final response = await _dio.post(
        '/api/WordAutomation/arbeitsordner/aufraeumen',
        data: {'vorgangSchluessel': vorgangSchluessel},
        options: Options(contentType: Headers.jsonContentType),
      );
      return ArbeitsordnerAufraeumung.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Die Arbeitskopie konnte nicht gelöscht werden',
            ),
      );
    }
  }

  @override
  Future<Uint8List> convertDocxToPdf(String docxFilePath) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post<List<int>>(
        '/api/PdfConversion/convert-from-path',
        data: {'docxFilePath': docxFilePath},
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.bytes,
          // Die Word-Konvertierung kann (kalt) mehrere Sekunden dauern —
          // bewusst länger als der globale 3-s-Timeout aus dem NetworkModule.
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      stopwatch.stop();
      developer.log(
        'PDF-Konvertierung (Dio POST): ${stopwatch.elapsedMilliseconds} ms',
        name: 'PERF',
      );

      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      stopwatch.stop();
      developer.log(
        'PDF-Konvertierung FEHLGESCHLAGEN nach ${stopwatch.elapsedMilliseconds} ms',
        name: 'PERF',
      );
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Die PDF-Vorschau konnte nicht erstellt werden',
            ),
      );
    }
  }

  @override
  Future<RvgCalculation> calculateRvgFees(
    double gegenstandswert,
    double gebuehrensatz,
    bool applyVat, {
    double? geschaeftsgebuehrOverride,
    double? auslagenpauschaleOverride,
  }) async {
    try {
      final response = await _dio.post(
        '/api/WordAutomation/rvg-calculation',
        data: {
          'gegenstandswert': gegenstandswert,
          'gebuehrensatz': gebuehrensatz,
          'applyVat': applyVat,
          'geschaeftsgebuehrOverride': geschaeftsgebuehrOverride,
          'auslagenpauschaleOverride': auslagenpauschaleOverride,
        },
        options: Options(contentType: Headers.jsonContentType),
      );

      final data = response.data as Map<String, dynamic>;
      return RvgCalculation(
        gegenstandswert: (data['gegenstandswert'] as num).toDouble(),
        gebuehrensatz: (data['gebuehrensatz'] as num).toDouble(),
        wertgebuehr: (data['wertgebuehr'] as num).toDouble(),
        geschaeftsgebuehr: (data['geschaeftsgebuehr'] as num).toDouble(),
        auslagenpauschale: (data['auslagenpauschale'] as num).toDouble(),
        netto: (data['netto'] as num).toDouble(),
        umsatzsteuer: (data['umsatzsteuer'] as num).toDouble(),
        brutto: (data['brutto'] as num).toDouble(),
      );
    } on DioException catch (e) {
      throw Exception(
        backendFehlertext(e) ??
            dienstOhneAntwort(
              e,
              'Die RVG-Kosten konnten nicht berechnet werden',
            ),
      );
    }
  }
}
