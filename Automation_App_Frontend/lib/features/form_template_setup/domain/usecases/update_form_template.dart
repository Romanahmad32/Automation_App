import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/repositories/form_template_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<FormTemplate, UpdateFormTemplateParams>)
class UpdateFormTemplate
    implements UseCase<FormTemplate, UpdateFormTemplateParams> {
  final FormTemplateRepository _templateRepository;

  UpdateFormTemplate(this._templateRepository);

  @override
  Future<Either<Failure, FormTemplate>> call(UpdateFormTemplateParams params) {
    return _templateRepository.updateFormTemplate(params.formTemplate);
  }
}

class UpdateFormTemplateParams {
  final FormTemplate formTemplate;

  UpdateFormTemplateParams(this.formTemplate);
}
