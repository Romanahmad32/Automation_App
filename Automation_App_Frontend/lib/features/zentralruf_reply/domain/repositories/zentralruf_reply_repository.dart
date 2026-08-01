import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';

abstract class ZentralrufReplyRepository {
  Future<Either<Failure, ZentralrufReplyParseResult>> parseReply(
    ZentralrufReplyInput input,
  );
}
