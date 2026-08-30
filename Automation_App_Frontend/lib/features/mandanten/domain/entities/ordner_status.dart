import 'package:equatable/equatable.dart';

/// Die Entscheidung, die zu einem Akten-Ordner getroffen wurde, der keinem
/// Mandanten gehört. Heute genau eine — der Wert steht so im HTTP-Vertrag
/// (`OrdnerStatusDto.status`).
enum OrdnerStatusArt {
  ohneMandantenbezug('ohneMandantenbezug', 'Ohne Mandantenbezug');

  const OrdnerStatusArt(this.wert, this.bezeichnung);

  /// Der Wert auf der Leitung.
  final String wert;

  /// Anzeigename.
  final String bezeichnung;

  static OrdnerStatusArt? ausWert(String? wert) {
    for (final art in OrdnerStatusArt.values) {
      if (art.wert == wert) return art;
    }
    return null;
  }
}

/// Ein Ordner, für den entschieden ist, dass er keinem Mandanten zugeordnet
/// werden muss (§6.1) — ein dritter Zustand neben *zugeordnet* und *offen*.
///
/// Wie die Zuordnung hängt der Vermerk am **Ordnernamen**, nicht am Pfad: ein
/// im Explorer umbenannter Ordner taucht wieder als offen auf.
class OrdnerStatus extends Equatable {
  final String ordnername;
  final OrdnerStatusArt art;

  /// Wann die Entscheidung getroffen wurde.
  final DateTime gesetztAm;

  const OrdnerStatus({
    required this.ordnername,
    required this.art,
    required this.gesetztAm,
  });

  /// Ein unbekannter Status kommt als [OrdnerStatusArt.ohneMandantenbezug] an:
  /// eine neuere Backend-Fassung darf die Liste erweitern, ohne dass eine
  /// ältere Oberfläche den Vermerk verliert und der Ordner still zurück in den
  /// Stapel fällt.
  factory OrdnerStatus.fromJson(Map<String, dynamic> json) => OrdnerStatus(
    ordnername: json['ordnername'] as String? ?? '',
    art:
        OrdnerStatusArt.ausWert(json['status'] as String?) ??
        OrdnerStatusArt.ohneMandantenbezug,
    gesetztAm:
        DateTime.tryParse(json['gesetztAm'] as String? ?? '') ?? DateTime.now(),
  );

  @override
  List<Object?> get props => [ordnername, art, gesetztAm];
}
