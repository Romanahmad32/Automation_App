part of 'rvg_calculation_bloc.dart';

sealed class RvgCalculationEvent extends Equatable {
  const RvgCalculationEvent();
}

final class CalculateRvgEvent extends RvgCalculationEvent {
  final double gegenstandswert;
  final double gebuehrensatz;
  final bool applyVat;

  /// Manuell korrigierte Geschäftsgebühr in €; null = automatisch berechnen.
  final double? geschaeftsgebuehrOverride;

  /// Manuell korrigierte Auslagenpauschale in €; null = automatisch berechnen.
  final double? auslagenpauschaleOverride;

  const CalculateRvgEvent({
    required this.gegenstandswert,
    required this.gebuehrensatz,
    required this.applyVat,
    this.geschaeftsgebuehrOverride,
    this.auslagenpauschaleOverride,
  });

  @override
  List<Object?> get props => [
    gegenstandswert,
    gebuehrensatz,
    applyVat,
    geschaeftsgebuehrOverride,
    auslagenpauschaleOverride,
  ];
}
