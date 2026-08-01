import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:automation_app/features/zentralruf_request/domain/repositories/zentralruf_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<ZentralrufPrefillResult, ZentralrufRequest>)
class PrefillZentralrufForm
    implements UseCase<ZentralrufPrefillResult, ZentralrufRequest> {
  final ZentralrufRepository repository;

  PrefillZentralrufForm({required this.repository});

  @override
  Future<Either<Failure, ZentralrufPrefillResult>> call(
    ZentralrufRequest params,
  ) async {
    return repository.prefillForm(params);
  }
}
