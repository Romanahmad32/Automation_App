import 'package:equatable/equatable.dart';

/// Was beim Griff nach Outlook herauskam (§4.7) — nicht nur die Dateien,
/// sondern auch, aus **welcher** Nachricht sie stammen.
///
/// Der Griff ist der einzige Schritt des Ablaufs, dessen Eingabe der Anwalt
/// nicht in dieser App gewählt hat: Gelesen wird die Nachricht, die in Outlook
/// gerade in einem eigenen Fenster offen ist, sonst die in der Liste markierte.
/// Ohne Betreff und Absender bekäme er Dateien vorgelegt, ohne zu wissen,
/// woher — und ein Griff in die falsche Nachricht sähe aus wie ein richtiger.
class OutlookAnhaenge extends Equatable {
  /// Die abgelegten Anhänge mit vollem Pfad.
  final List<String> pfade;

  /// Betreff der gelesenen Nachricht; leer, wenn keine da war.
  final String betreff;

  final String absender;

  /// True, wenn die Nachricht in einem eigenen Fenster offen stand; false, wenn
  /// sie nur in der Liste markiert war. Genau diese Regel erklärt, warum die
  /// Anhänge einer anderen Mail kamen als erwartet.
  final bool ausOffenemFenster;

  /// False, wenn Outlook überhaupt nicht geantwortet hat — nicht installiert,
  /// nicht gestartet, oder der Zugriff lief in die Zeitgrenze. Von „nichts
  /// ausgewählt" zu unterscheiden, weil der Anwalt sonst am falschen Ende sucht.
  final bool outlookErreicht;

  const OutlookAnhaenge({
    this.pfade = const [],
    this.betreff = '',
    this.absender = '',
    this.ausOffenemFenster = false,
    this.outlookErreicht = true,
  });

  factory OutlookAnhaenge.fromJson(Map<String, dynamic> json) =>
      OutlookAnhaenge(
        pfade: [
          for (final pfad in (json['pfade'] as List?) ?? const [])
            pfad as String,
        ],
        betreff: json['betreff'] as String? ?? '',
        absender: json['absender'] as String? ?? '',
        ausOffenemFenster: json['ausOffenemFenster'] as bool? ?? false,
        outlookErreicht: json['outlookErreicht'] as bool? ?? true,
      );

  /// True, wenn Outlook eine Nachricht gelesen hat — sie kann trotzdem ohne
  /// Anhang gewesen sein.
  bool get hatNachricht => outlookErreicht && betreff.isNotEmpty;

  /// Die Nachricht in einer Zeile, so wie sie in Outlook steht.
  String get bezeichnung =>
      absender.isEmpty ? '„$betreff"' : '„$betreff" von $absender';

  @override
  List<Object?> get props => [
    pfade,
    betreff,
    absender,
    ausOffenemFenster,
    outlookErreicht,
  ];
}
