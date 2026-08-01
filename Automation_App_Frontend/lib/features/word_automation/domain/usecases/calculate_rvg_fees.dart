import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/rvg_calculation.dart';
import 'package:automation_app/features/word_automation/domain/repositories/word_automation_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<RvgCalculation, CalculateRvgFeesParams>)
class CalculateRvgFees
    implements UseCase<RvgCalculation, CalculateRvgFeesParams> {
  final WordAutomationRepository repository;

  CalculateRvgFees({required this.repository});

  @override
  Future<Either<Failure, RvgCalculation>> call(
      CalculateRvgFeesParams params,) async {
    return repository.calculateRvgFees(
      params.gegenstandswert,
      params.gebuehrensatz,
      params.applyVat,
      geschaeftsgebuehrOverride: params.geschaeftsgebuehrOverride,
      auslagenpauschaleOverride: params.auslagenpauschaleOverride,
    );
  }
}

class CalculateRvgFeesParams {
  final double gegenstandswert;
  final double gebuehrensatz;
  final bool applyVat;
  final double? geschaeftsgebuehrOverride;
  final double? auslagenpauschaleOverride;

  const CalculateRvgFeesParams({
    required this.gegenstandswert,
    required this.gebuehrensatz,
    required this.applyVat,
    this.geschaeftsgebuehrOverride,
    this.auslagenpauschaleOverride,
  });
}
