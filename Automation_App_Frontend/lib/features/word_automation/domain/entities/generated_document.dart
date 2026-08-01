import 'package:equatable/equatable.dart';

/// Ergebnis einer Vorlagen-Befüllung im Backend: Pfad des erzeugten Dokuments
/// plus Warnungen (z. B. nicht ersetzte Platzhalter, Anforderung 3.4).
class GeneratedDocument extends Equatable {
  final String outputFilePath;
  final List<String> warnings;

  const GeneratedDocument({
    required this.outputFilePath,
    this.warnings = const [],
  });

  @override
  List<Object> get props => [outputFilePath, warnings];
}
