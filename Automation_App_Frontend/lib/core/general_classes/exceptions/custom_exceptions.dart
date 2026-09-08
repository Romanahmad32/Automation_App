class FormTemplateException implements Exception {
  final String message;

  const FormTemplateException(this.message);

  @override
  String toString() => 'FormTemplateException: $message';
}

class SettingsException implements Exception {
  final String message;

  const SettingsException(this.message);

  @override
  String toString() => 'SettingsException: $message';
}

class MandantException implements Exception {
  final String message;

  const MandantException(this.message);

  @override
  String toString() => 'MandantException: $message';
}

/// Fachliche Auskunft aus dem Registerimport (§6.2) — eine Datei, die sich
/// nicht lesen lässt, oder eine Fassung, die der Dienst nicht kennt.
class RegisterException implements Exception {
  final String message;

  const RegisterException(this.message);

  @override
  String toString() => 'RegisterException: $message';
}
