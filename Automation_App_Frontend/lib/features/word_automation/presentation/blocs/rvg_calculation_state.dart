part of 'rvg_calculation_bloc.dart';

sealed class RvgCalculationState extends Equatable {
  const RvgCalculationState();
}

final class RvgCalculationInitial extends RvgCalculationState {
  @override
  List<Object?> get props => [];
}

final class RvgCalculationLoading extends RvgCalculationState {
  @override
  List<Object?> get props => [];
}

final class RvgCalculationLoaded extends RvgCalculationState {
  final RvgCalculation calculation;

  const RvgCalculationLoaded(this.calculation);

  @override
  List<Object?> get props => [calculation];
}

final class RvgCalculationError extends RvgCalculationState {
  final String message;

  const RvgCalculationError(this.message);

  @override
  List<Object?> get props => [message];
}
