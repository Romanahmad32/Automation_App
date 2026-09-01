/// Die Platzhalter, die in einer Mail-Textvorlage stehen dürfen (§4.7) — in
/// derselben Schreibweise wie in den Word-Vorlagen: `{{Name}}`.
///
/// Zwei Herkünfte, und die Reihenfolge entscheidet: [anrede] und [grussformel]
/// beantwortet der Versand selbst, weil beide von den **Empfängern** dieser
/// einen Mail abhängen und nicht vom Vorgang. Alles Übrige löst die vorhandene
/// Ersetzung der Formularvorlagen auf (`FeldDatenquelleErkennung` →
/// `VorgangPrefillMatcher`) — dieselben Namen, dieselbe Schreibweise, damit
/// niemand zwei Kataloge im Kopf behalten muss.
class MailPlatzhalter {
  const MailPlatzhalter._();

  /// Die Anrede der Mail. Sie steht in der Vorlage und nicht davor, damit jede
  /// Vorlage selbst bestimmt, ob und wie angeredet wird.
  static const String anrede = 'Anrede';

  /// Die persönliche Grußformel des Mandanten (§5.1) — leer, sobald noch
  /// jemand anderes im Feld „An" steht.
  static const String grussformel = 'Grussformel';

  /// Findet `{{Name}}` samt Namen. Bewusst dieselbe Form wie im Backend
  /// (`WordAutomationService`); wer sie hier ändert, hat zwei Schreibweisen.
  static final RegExp muster = RegExp(r'\{\{\s*([^{}]+?)\s*\}\}');

  /// Was die Verwaltung als Hilfe unter dem Textfeld zeigt. Keine
  /// vollständige Liste — der Katalog der Vorgangsfelder ist lang, und eine
  /// Aufzählung davon veraltet hier stillschweigend.
  static const List<String> haeufige = [
    anrede,
    grussformel,
    'MandantName',
    'VersichererName',
    'Aktenzeichen',
    'Unfalldatum',
  ];
}
