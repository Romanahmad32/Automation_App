import 'package:automation_app/core/backend/backend_endpoint.dart';
import 'package:automation_app/core/network/textual_log_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@module
abstract class NetworkModule {
  @singleton
  Dio get dio =>
      Dio(
          BaseOptions(
            baseUrl: BackendEndpoint.basisUrl,
            connectTimeout: const Duration(seconds: 3),
            receiveTimeout: const Duration(seconds: 3),
          ),
        )
        // Protokolliert JSON-/Text-Antworten weiterhin, lässt aber Binärdaten
        // (z. B. die PDF-Konvertierung) weg, damit das Terminal nicht mit
        // Byte-Listen geflutet wird.
        ..interceptors.add(TextualLogInterceptor());
}
