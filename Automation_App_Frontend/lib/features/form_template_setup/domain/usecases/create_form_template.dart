import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/repositories/form_template_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<void, CreateFormTemplateRequest>)
class CreateFormTemplate implements UseCase<void, CreateFormTemplateRequest> {
  final FormTemplateRepository _templateRepository;

  CreateFormTemplate(this._templateRepository);

  @override
  Future<Either<Failure, void>> call(CreateFormTemplateRequest params) {
    return _templateRepository.createFormTemplate(params);
  }
}
