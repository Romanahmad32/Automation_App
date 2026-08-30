import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:equatable/equatable.dart';

/// Ein **angefangener** Ausfüllstand des Word-Assistenten zu einem Vorgang
/// (§4.4): was im Formular stand und welche Schadenspositionen erfasst waren,
/// als zuletzt gesichert wurde.
///
/// Streng getrennt von `Vorgang.feldWerte`: Dort stehen **bestätigte** Werte —
/// solche, aus denen ein Dokument entstanden ist. Ein Entwurf ist nur ein
/// Angebot. Er wird deshalb beim Wiedereinstieg angezeigt und nicht still
/// eingesetzt; der Anwalt sieht, woher die Werte kommen, bevor sie in seinem
/// Schreiben landen.
///
/// [gespeichertAm] trägt die Leiste beim Wiedereinstieg („Angefangener Stand
/// von 14:32") — ohne Zeitpunkt weiß niemand, ob das Angebot von eben stammt
/// oder von vorletzter Woche.
class VorgangEntwurf extends Equatable {
  final DateTime gespeichertAm;
  final Map<String, String> feldWerte;
  final DamageListing? schadensaufstellung;

  const VorgangEntwurf({
    required this.gespeichertAm,
    this.feldWerte = const {},
    this.schadensaufstellung,
  });

  /// Ob hier nichts steht, was der Mühe eines Angebots wert wäre: kein
  /// ausgefülltes Feld und keine Position. Ein leerer Entwurf wird gar nicht
  /// erst gespeichert — sonst begrüßt die Leiste den Anwalt mit einem Angebot,
  /// das ihm nichts zurückgibt.
  bool get istLeer =>
      feldWerte.values.every((wert) => wert.trim().isEmpty) &&
      (schadensaufstellung?.items.isEmpty ?? true);

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
