import 'package:equatable/equatable.dart';

/// Was der Versand ergeben hat (§4.7). Der Zeitpunkt begründet später das
/// vorbelegte Häkchen im Abschlussdialog — abgeschlossen wird der Vorgang
/// trotzdem von Hand (§4.8).
class EmailVersandErgebnis extends Equatable {
  final DateTime gesendetAm;
  final List<String> empfaenger;

  /// True, wenn die Nachricht nachweislich im Ordner „Gesendet" liegt — der
  /// einzige Versandnachweis, den §4.7 vorsieht.
  final bool imGesendetOrdner;

  /// Nebenbefund, der den Versand nicht verhindert hat; sonst null.
  final String? hinweis;

  const EmailVersandErgebnis({
    required this.gesendetAm,
    required this.empfaenger,
    required this.imGesendetOrdner,
    this.hinweis,
  });

  factory EmailVersandErgebnis.fromJson(Map<String, dynamic> json) {
    return EmailVersandErgebnis(
      gesendetAm:
          DateTime.tryParse(json['gesendetAm'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      empfaenger:
          (json['empfaenger'] as List?)?.whereType<String>().toList() ??
          const [],
      imGesendetOrdner: json['imGesendetOrdner'] as bool? ?? false,
      hinweis: json['hinweis'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    gesendetAm,
    empfaenger,
    imGesendetOrdner,
    hinweis,
  ];
}
