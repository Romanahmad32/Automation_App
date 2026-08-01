import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/repositories/form_template_repository.dart';
import 'package:injectable/injectable.dart';

class GetTemplatePlaceholdersParams {
  final String wordFilePath;

  const GetTemplatePlaceholdersParams(this.wordFilePath);
}

@Injectable(as: UseCase<List<String>, GetTemplatePlaceholdersParams>)
class GetTemplatePlaceholders
    implements UseCase<List<String>, GetTemplatePlaceholdersParams> {
  final FormTemplateRepository _templateRepository;

  GetTemplatePlaceholders(this._templateRepository);

  @override
  Future<Either<Failure, List<String>>> call(
      GetTemplatePlaceholdersParams params,) {
    return _templateRepository.getTemplatePlaceholders(params.wordFilePath);
  }
}
