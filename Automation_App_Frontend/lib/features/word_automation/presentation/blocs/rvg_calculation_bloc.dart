import 'dart:async';

import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/rvg_calculation.dart';
import 'package:automation_app/features/word_automation/domain/usecases/calculate_rvg_fees.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

part 'rvg_calculation_event.dart';
part 'rvg_calculation_state.dart';

/// Holt die RVG-Kostenberechnung für die Live-Vorschau der Schadensaufstellung
/// vom Backend. Debounced: restartable() bricht den wartenden Handler bei
/// jedem neuen Event ab, das Delay am Handler-Anfang bündelt schnelle Eingaben.
@injectable
class RvgCalculationBloc
    extends Bloc<RvgCalculationEvent, RvgCalculationState> {
  static const _debounce = Duration(milliseconds: 350);

  final UseCase<RvgCalculation, CalculateRvgFeesParams> _calculateRvgFees;

  RvgCalculationBloc(this._calculateRvgFees) : super(RvgCalculationInitial()) {
    on<CalculateRvgEvent>(_onCalculateRvgEvent, transformer: restartable());
  }

  Future<void> _onCalculateRvgEvent(
    CalculateRvgEvent event,
    Emitter<RvgCalculationState> emit,
  ) async {
    // Ohne gültige Positionen gibt es nichts zu berechnen (Backend würde 400 liefern).
    if (event.gegenstandswert <= 0) {
      emit(RvgCalculationInitial());
      return;
    }

    await Future.delayed(_debounce);

    emit(RvgCalculationLoading());
    final result = await _calculateRvgFees(
      CalculateRvgFeesParams(
        gegenstandswert: event.gegenstandswert,
        gebuehrensatz: event.gebuehrensatz,
        applyVat: event.applyVat,
        geschaeftsgebuehrOverride: event.geschaeftsgebuehrOverride,
        auslagenpauschaleOverride: event.auslagenpauschaleOverride,
      ),
    );

    switch (result) {
      case Left(value: final failure):
        emit(RvgCalculationError(failure.message));
      case Right(value: final calculation):
        emit(RvgCalculationLoaded(calculation));
    }
  }
}
