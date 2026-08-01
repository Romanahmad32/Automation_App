import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';

/// Zugriff auf die vom Backend gepflegte Versicherer-Wissensbasis (nur lesend —
/// das Register wird ausschließlich automatisch aus Zentralruf-Antworten
/// befüllt).
abstract class VersichererRepository {
  Future<List<Versicherer>> ladeVersicherer();
}
