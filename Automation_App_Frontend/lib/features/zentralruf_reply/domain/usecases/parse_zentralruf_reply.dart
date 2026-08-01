import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/domain/repositories/zentralruf_reply_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<ZentralrufReplyParseResult, ZentralrufReplyInput>)
class ParseZentralrufReply
    implements UseCase<ZentralrufReplyParseResult, ZentralrufReplyInput> {
  final ZentralrufReplyRepository repository;

  ParseZentralrufReply({required this.repository});

  @override
  Future<Either<Failure, ZentralrufReplyParseResult>> call(
    ZentralrufReplyInput params,
  ) async {
    return repository.parseReply(params);
  }
}
