class ZentralrufPrefillResult {
  /// Die in das Formular eingetragene Referenz, z. B. "84/26 C03_GG-XY 123".
  final String referenz;

  final List<String> filledFields;

  /// Felder, die nicht automatisch gefüllt werden konnten und manuell zu prüfen sind.
  final List<String> skippedFields;

  const ZentralrufPrefillResult({
    required this.referenz,
    required this.filledFields,
    required this.skippedFields,
  });
}
