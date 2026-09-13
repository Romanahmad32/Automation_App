import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:equatable/equatable.dart';

/// Ein **angefangener** Ausfüllstand des Word-Assistenten zu einem Vorgang
/// (§4.4): was im Formular stand und welche Schadenspositionen erfasst waren,
/// als zuletzt gesichert wurde.
///
/// Streng getrennt von `Vorgang.feldWerte`: Dort stehen **bestätigte** Werte —
/// solche, aus denen ein Dokument entstanden ist. Hier steht, was der Anwalt
/// zuletzt getippt hatte, als er wegging.
///
/// [feldWerte] enthält nur die Felder, die von der **Vorbelegung** abweichen
/// (`EntwurfAbweichung`, #133) — der ganze Formularstand fröre sonst die
/// Vorbelegung ein und verdeckte eine später eintreffende Zentralruf-Antwort.
/// Beim Wiedereinstieg kommen diese Werte still zurück: Das Formular zeigt
/// Vorbelegung und Entwurf gemischt, der Entwurf gewinnt an seinen Feldern, und
/// der Weg zurück ist „Eingaben auf Vorbelegung zurücksetzen".
///
/// [gespeichertAm] sagt, wie alt der Stand ist — ohne Zeitpunkt ließe sich ein
/// Entwurf von eben nicht von einem von vorletzter Woche unterscheiden, wenn
/// jemand ihn einmal anzeigen oder aufräumen will.
class VorgangEntwurf extends Equatable {
  final DateTime gespeichertAm;
  final Map<String, String> feldWerte;
  final DamageListing? schadensaufstellung;

  const VorgangEntwurf({
    required this.gespeichertAm,
    this.feldWerte = const {},
    this.schadensaufstellung,
  });

  factory VorgangEntwurf.fromJson(Map<String, dynamic> json) {
    final werte = json['feldWerte'];
    final aufstellung = json['schadensaufstellung'];
    return VorgangEntwurf(
      gespeichertAm:
          DateTime.tryParse(json['gespeichertAm'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      feldWerte: werte is Map<String, dynamic>
          ? {
              for (final eintrag in werte.entries)
                if (eintrag.value is String)
                  eintrag.key: eintrag.value as String,
            }
          : const {},
      schadensaufstellung: aufstellung is Map<String, dynamic>
          ? DamageListing.fromJson(aufstellung)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'gespeichertAm': gespeichertAm.toIso8601String(),
    'feldWerte': feldWerte,
    'schadensaufstellung': schadensaufstellung?.toJson(),
  };

  @override
  List<Object?> get props => [gespeichertAm, feldWerte, schadensaufstellung];
}
