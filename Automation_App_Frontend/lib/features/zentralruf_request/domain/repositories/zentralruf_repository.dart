import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';

abstract class ZentralrufRepository {
  Future<Either<Failure, ZentralrufPrefillResult>> prefillForm(
    ZentralrufRequest request,
  );
}
