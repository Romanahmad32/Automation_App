import 'package:equatable/equatable.dart';

/// Wie ein Druck- oder Öffnen-Auftrag ausgegangen ist — die Werte des Feldes
/// `status` im `VollmachtErgebnisDto`.
enum VollmachtErgebnisStatus {
  /// An den Drucker übergeben; die Arbeitsdatei ist im Dienst wieder gelöscht.
  gedruckt('gedruckt'),

  /// Ausgefüllt, aber nicht gedruckt — die Datei liegt unter `pfad` bereit.
  druckFehlgeschlagen('druckFehlgeschlagen'),

  /// Ausgefüllt und bewusst nicht gedruckt („In Word öffnen").
  ausgefuellt('ausgefuellt'),

  /// Die Vorlage dieser Art liegt nicht im Vorlagenordner.
  vorlageFehlt('vorlageFehlt'),

  /// Ausfüllen gescheitert; `meldung` sagt, woran.
  fehler('fehler');

  final String wert;

  const VollmachtErgebnisStatus(this.wert);

  /// Ein unbekannter Wert ist ein [fehler] — nie still ein Erfolg.
  static VollmachtErgebnisStatus ausWert(String? wert) {
    for (final status in values) {
      if (status.wert == wert) return status;
    }
    return fehler;
  }
}

/// Antwort des Dienstes auf einen Vollmacht-Auftrag (§4.11).
class VollmachtErgebnis extends Equatable {
  final VollmachtErgebnisStatus status;

  /// Die ausgefüllte Datei, sofern sie zum Öffnen bereitliegt.
  final String? pfad;

  /// Klartext für den Anwalt; leer bei [VollmachtErgebnisStatus.gedruckt].
  final String? meldung;

  /// Platzhalter, die in der Vorlage stehen geblieben sind (§4.4).
  final List<String> warnungen;

  const VollmachtErgebnis({
    required this.status,
    this.pfad,
    this.meldung,
    this.warnungen = const [],
  });

  factory VollmachtErgebnis.fromJson(Map<String, dynamic> json) =>
      VollmachtErgebnis(
        status: VollmachtErgebnisStatus.ausWert(json['status'] as String?),
        pfad: json['pfad'] as String?,
        meldung: json['meldung'] as String?,
        warnungen: [
          for (final warnung in json['warnungen'] as List? ?? const [])
            if (warnung is String) warnung,
        ],
      );

  @override
  List<Object?> get props => [status, pfad, meldung, warnungen];
}
