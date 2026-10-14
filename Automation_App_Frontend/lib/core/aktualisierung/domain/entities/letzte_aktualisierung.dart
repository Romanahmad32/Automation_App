import 'package:equatable/equatable.dart';

/// Wie die letzte Aktualisierung ausgegangen ist (#196) — aus der Merkdatei,
/// die der Dienst vor dem Start des Installers schreibt und beim nächsten
/// Start auswertet. Steht im Stand, bis das Frontend es quittiert hat.
class LetzteAktualisierung extends Equatable {
  const LetzteAktualisierung({
    required this.zielVersion,
    required this.erfolgreich,
  });

  /// Worauf aktualisiert werden sollte, dreistellig ohne `v`.
  final String zielVersion;

  /// Ob die laufende Version mindestens [zielVersion] ist.
  final bool erfolgreich;

  factory LetzteAktualisierung.fromJson(Map<String, dynamic> json) =>
      LetzteAktualisierung(
        zielVersion: json['zielVersion'] as String? ?? '',
        erfolgreich: json['erfolgreich'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [zielVersion, erfolgreich];
}
