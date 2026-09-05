/// Der gefundene synchronisierte Wurzelordner samt der Umgebungsvariablen, aus
/// der er stammt.
///
/// Beides zusammen, weil der Pfad allein nicht reicht: Ein Rechner mit
/// Geschäfts-OneDrive und einer mit privatem haben verschiedene Wurzeln, und
/// `SynchronisierterOrdner` bevorzugt das Geschäftskonto. Wer einen Ordner
/// relativ zu „der Wurzel" ablegt, ohne festzuhalten, *welche* gemeint war,
/// löst denselben relativen Pfad auf dem zweiten Rechner still in einem
/// anderen Baum auf (#103).
///
/// Gerechnet wird mit diesem Anker im Dienst — das Frontend zeigt ihn nur an
/// und schickt beim Speichern den vollen Pfad. Deshalb steht hier eine
/// schlichte Ergebnisklasse und keine Pfadmathematik.
class SynchronisierterWurzelOrdner {
  /// Name der Umgebungsvariablen, die getroffen hat: `OneDriveCommercial`,
  /// `OneDriveConsumer` oder `OneDrive`.
  final String variable;

  /// Der Wurzelordner selbst — ohne Unterordner, so wie er in der Variablen
  /// steht.
  final String pfad;

  const SynchronisierterWurzelOrdner({
    required this.variable,
    required this.pfad,
  });

  @override
  String toString() => 'SynchronisierterWurzelOrdner($variable, $pfad)';
}
