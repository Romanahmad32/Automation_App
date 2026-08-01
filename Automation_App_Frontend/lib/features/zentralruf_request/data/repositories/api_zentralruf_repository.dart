import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/zentralruf_request/data/datasources/zentralruf_datasource.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart';
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart';
import 'package:automation_app/features/zentralruf_request/domain/repositories/zentralruf_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: ZentralrufRepository)
class ApiZentralrufRepository implements ZentralrufRepository {
  final ZentralrufDatasource datasource;

  ApiZentralrufRepository(this.datasource);

  @override
  Future<Either<Failure, ZentralrufPrefillResult>> prefillForm(
      ZentralrufRequest request,) async {
    try {
      final result = await datasource.prefillForm(request);
      return Right(result);
    } catch (e) {
      // "Exception: "-Präfix entfernen — die Meldung wird dem Anwender angezeigt.
      return Left(
        ServerFailure(message: e.toString().replaceFirst('Exception: ', '')),
      );
    }
  }
}
