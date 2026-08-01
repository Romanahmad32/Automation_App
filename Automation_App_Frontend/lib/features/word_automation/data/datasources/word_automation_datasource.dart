import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart';
import 'package:automation_app/features/word_automation/domain/entities/rvg_calculation.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class WordAutomationDatasource {
  Future<GeneratedDocument> fillOutTemplate(
    String path,
    Map<String, String> values, {
    DamageListing? damageListing,
    bool? vorsteuerabzugsberechtigt,
    String? outputFileName,
  });

  Future<Uint8List> convertDocxToPdf(String docxFilePath);

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
  Future<GeneratedDocument> fillOutTemplate(
    String path,
    Map<String, String> values, {
    DamageListing? damageListing,
    bool? vorsteuerabzugsberechtigt,
    String? outputFileName,
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
          if (vorsteuerabzugsberechtigt != null)
            'vorsteuerabzugsberechtigt': vorsteuerabzugsberechtigt,
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
        _serverMessage(e) ??
            'Beim bearbeiten des Word-Dokuments ist ein Fehler aufgetreten',
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
        _serverMessage(e) ?? 'Die PDF-Vorschau konnte nicht erstellt werden',
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
        _serverMessage(e) ?? 'Die RVG-Kosten konnten nicht berechnet werden',
      );
    }
  }

  /// Liest eine vom Backend gelieferte Fehlermeldung aus der Response
  /// (z. B. die 503-Meldung "Microsoft Word ist nicht installiert …").
  String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is String && data.isNotEmpty) {
      return data;
    }
    if (data is List<int> && data.isNotEmpty) {
      return String.fromCharCodes(data);
    }
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? data['title'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }
}
