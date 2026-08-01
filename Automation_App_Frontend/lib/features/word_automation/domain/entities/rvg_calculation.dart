import 'package:equatable/equatable.dart';

/// Ergebnis der RVG-Kostenberechnung aus dem Backend (Single Source of Truth
/// ist der RvgFeeCalculator des Backends — die Klammertabelle nach § 13 RVG
/// wird bewusst nicht in Dart dupliziert).
class RvgCalculation extends Equatable {
  final double gegenstandswert;
  final double gebuehrensatz;
  final double wertgebuehr;
  final double geschaeftsgebuehr;
  final double auslagenpauschale;
  final double netto;
  final double umsatzsteuer;
  final double brutto;

  const RvgCalculation({
    required this.gegenstandswert,
    required this.gebuehrensatz,
    required this.wertgebuehr,
    required this.geschaeftsgebuehr,
    required this.auslagenpauschale,
    required this.netto,
    required this.umsatzsteuer,
    required this.brutto,
  });

  @override
  List<Object?> get props => [
    gegenstandswert,
    gebuehrensatz,
    wertgebuehr,
    geschaeftsgebuehr,
    auslagenpauschale,
    netto,
    umsatzsteuer,
    brutto,
  ];
}
