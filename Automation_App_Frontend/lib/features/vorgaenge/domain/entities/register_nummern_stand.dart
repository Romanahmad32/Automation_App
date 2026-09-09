import 'package:equatable/equatable.dart';

/// Der Nummernstand eines Jahrgangs (§6.3) — das Gegenstück zu
/// `RegisterNummernDto` im Backend: der Vorschlag für die nächste laufende
/// Nummer und die im Jahrgang schon belegten, quellenübergreifend über
/// Vorgänge der App **und** die übernommene Historie (§6.2).
class RegisterNummernStand extends Equatable {
  /// Der Jahrgang, für den dieser Stand gilt (vierstellig, z. B. "2026").
  final String jahr;

  /// Die höchste im Jahrgang belegte laufende Nummer.
  final int hoechsteNummer;

  /// Der Vorschlag für den nächsten Vorgang: [hoechsteNummer] + 1.
  final int naechsteNummer;

  /// Alle im Jahrgang vergebenen Nummern, aufsteigend und ohne Doppelte.
  final List<int> belegte;

  const RegisterNummernStand({
    required this.jahr,
    required this.hoechsteNummer,
    required this.naechsteNummer,
    required this.belegte,
  });

  /// Ob [nummer] im Jahrgang schon vergeben ist — die Warnung am Feld (§6.3)
  /// hängt allein davon ab. Sie sperrt bewusst nicht: Das gewachsene Register
  /// der Kanzlei enthält echte Doubletten.
  bool istBelegt(int nummer) => belegte.contains(nummer);

  factory RegisterNummernStand.fromJson(Map<String, dynamic> json) =>
      RegisterNummernStand(
        jahr: json['jahr'] as String? ?? '',
        hoechsteNummer: (json['hoechsteNummer'] as num?)?.toInt() ?? 0,
        naechsteNummer: (json['naechsteNummer'] as num?)?.toInt() ?? 1,
        belegte: [
          for (final nummer in (json['belegte'] as List? ?? const []))
            (nummer as num).toInt(),
        ],
      );

  @override
  List<Object?> get props => [jahr, hoechsteNummer, naechsteNummer, belegte];
}
