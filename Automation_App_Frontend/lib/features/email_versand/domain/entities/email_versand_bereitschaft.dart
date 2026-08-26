import 'package:equatable/equatable.dart';

/// Ob die App senden kann und von welcher Adresse aus (§4.7). Wird abgefragt,
/// **bevor** der Anwalt zu tippen beginnt — einen fertigen Text an einer
/// fehlenden Anmeldung scheitern zu lassen, ist die teuerste Art, das zu
/// erfahren.
class EmailVersandBereitschaft extends Equatable {
  final bool bereit;
  final String absender;

  /// Grund im Klartext, wenn nicht bereit; sonst null.
  final String? hinweis;

  const EmailVersandBereitschaft({
    required this.bereit,
    this.absender = '',
    this.hinweis,
  });

  factory EmailVersandBereitschaft.fromJson(Map<String, dynamic> json) {
    return EmailVersandBereitschaft(
      bereit: json['bereit'] as bool? ?? false,
      absender: json['absender'] as String? ?? '',
      hinweis: json['hinweis'] as String?,
    );
  }

  @override
  List<Object?> get props => [bereit, absender, hinweis];
}
