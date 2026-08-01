import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/repositories/form_template_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<void, DeleteFormTemplateParams>)
class DeleteFormTemplate implements UseCase<void, DeleteFormTemplateParams> {
  final FormTemplateRepository _templateRepository;

  DeleteFormTemplate(this._templateRepository);

  @override
  Future<Either<Failure, void>> call(DeleteFormTemplateParams params) {
    return _templateRepository.deleteFormTemplate(params.id);
  }
}

class DeleteFormTemplateParams {
  final int id;

  DeleteFormTemplateParams(this.id);
}
