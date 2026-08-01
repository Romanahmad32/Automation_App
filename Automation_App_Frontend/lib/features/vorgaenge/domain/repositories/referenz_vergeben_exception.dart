/// Wird geworfen, wenn die Zielreferenz einer Referenzänderung bereits einem
/// anderen Vorgang gehört (Backend antwortet 409). Die Referenz ist der
/// fachliche Schlüssel des Vorgangs und muss eindeutig bleiben.
class ReferenzVergebenException implements Exception {
  final String referenz;

  const ReferenzVergebenException(this.referenz);

  @override
  String toString() => 'Referenz bereits vergeben: $referenz';
}
