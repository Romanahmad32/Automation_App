import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/repositories/form_template_repository.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: UseCase<List<FormTemplate>, NoParams>)
class GetFormTemplates implements UseCase<List<FormTemplate>, NoParams> {
  final FormTemplateRepository _templateRepository;

  GetFormTemplates(this._templateRepository);

  @override
  Future<Either<Failure, List<FormTemplate>>> call(NoParams noParams) {
    return _templateRepository.getFormTemplates();
  }
}
