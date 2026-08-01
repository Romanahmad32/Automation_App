import 'dart:typed_data';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/repositories/word_automation_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<Uint8List, ConvertDocxToPdfParams>)
class ConvertDocxToPdf implements UseCase<Uint8List, ConvertDocxToPdfParams> {
  final WordAutomationRepository repository;

  ConvertDocxToPdf({required this.repository});

  @override
  Future<Either<Failure, Uint8List>> call(ConvertDocxToPdfParams params) {
    return repository.convertDocxToPdf(params.docxFilePath);
  }
}

class ConvertDocxToPdfParams {
  final String docxFilePath;

  const ConvertDocxToPdfParams({required this.docxFilePath});
}
