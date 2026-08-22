/// Der lesbare Teil einer Ausnahme — ohne das technische Präfix, das
/// `toString()` voranstellt ("Exception: …", "MandantException: …").
///
/// Diese Texte landen unverändert in einer SnackBar vor dem Anwalt. Ein
/// vorangestelltes "Exception:" ist für ihn kein Hinweis, sondern sieht nach
/// Defekt aus — und verdrängt bei knappem Platz den Teil, der ihm sagt, was zu
/// tun ist.
String ausnahmeText(Object ausnahme) {
  final text = ausnahme.toString().trim();
  final praefix = RegExp(r'^\w*(Exception|Error): ?').firstMatch(text);
  return praefix == null ? text : text.substring(praefix.end).trim();
}

abstract class Failure {
  final String message;

  Failure({required this.message});
}

class ServerFailure extends Failure {
  ServerFailure({required super.message});
}

class LocalFailure extends Failure {
  LocalFailure({required super.message});
}
