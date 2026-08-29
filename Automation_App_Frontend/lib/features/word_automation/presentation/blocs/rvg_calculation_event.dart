part of 'rvg_calculation_bloc.dart';

sealed class RvgCalculationEvent extends Equatable {
  const RvgCalculationEvent();
}

final class CalculateRvgEvent extends RvgCalculationEvent {
  final double gegenstandswert;
  final double gebuehrensatz;
  final bool applyVat;

  /// Ob überhaupt eine Position erfasst ist.
  ///
  /// Nötig, weil der [gegenstandswert] das nicht mehr verrät: `0` heißt
  /// entweder „keine Position" oder „lauter noch unbezifferte Positionen" —
  /// und das eine ist ein Reset, das andere eine gültige Berechnung. Der
  /// Aufrufer schickt auch den leeren Fall, damit `restartable()` eine noch
  /// laufende Anfrage zum alten Wert storniert.
  final bool hatPositionen;

  /// Manuell korrigierte Geschäftsgebühr in €; null = automatisch berechnen.
  final double? geschaeftsgebuehrOverride;

  /// Manuell korrigierte Auslagenpauschale in €; null = automatisch berechnen.
  final double? auslagenpauschaleOverride;

  const CalculateRvgEvent({
    required this.gegenstandswert,
    required this.gebuehrensatz,
    required this.applyVat,
    this.hatPositionen = true,
    this.geschaeftsgebuehrOverride,
    this.auslagenpauschaleOverride,
  });

  @override
  List<Object?> get props => [
    gegenstandswert,
    gebuehrensatz,
    applyVat,
    hatPositionen,
    geschaeftsgebuehrOverride,
    auslagenpauschaleOverride,
  ];
}
