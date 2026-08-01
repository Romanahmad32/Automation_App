import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/zentralruf_reply/data/datasources/zentralruf_reply_datasource.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/domain/repositories/zentralruf_reply_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: ZentralrufReplyRepository)
class ApiZentralrufReplyRepository implements ZentralrufReplyRepository {
  final ZentralrufReplyDatasource datasource;

  ApiZentralrufReplyRepository(this.datasource);

  @override
  Future<Either<Failure, ZentralrufReplyParseResult>> parseReply(
      ZentralrufReplyInput input,) async {
    try {
      final result = await datasource.parseReply(input);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
