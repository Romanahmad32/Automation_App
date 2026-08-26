import 'package:equatable/equatable.dart';

/// Wo der Entwurf gelandet ist, als die App ihn ans Mailprogramm übergeben hat
/// (§4.7). Gesendet wurde dabei nichts — das tut der Anwalt dort selbst, und
/// die App erfährt davon nichts mehr (§4.8).
class EmailEntwurfErgebnis extends Equatable {
  /// „outlook" oder „datei" — genau die Werte des Vertrags.
  final String weg;

  /// Klartext, wenn es nicht der Regelweg war; sonst null.
  final String? hinweis;

  const EmailEntwurfErgebnis({required this.weg, this.hinweis});

  /// True, wenn der Entwurf in Outlook steht — dann trägt er auch dessen
  /// Signatur. Beim Dateiweg fehlt sie und ist von Hand zu ergänzen.
  bool get inOutlook => weg == 'outlook';

  factory EmailEntwurfErgebnis.fromJson(Map<String, dynamic> json) {
    return EmailEntwurfErgebnis(
      weg: json['weg'] as String? ?? 'datei',
      hinweis: json['hinweis'] as String?,
    );
  }

  @override
  List<Object?> get props => [weg, hinweis];
}
