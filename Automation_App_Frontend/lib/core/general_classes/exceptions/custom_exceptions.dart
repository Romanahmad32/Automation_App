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
