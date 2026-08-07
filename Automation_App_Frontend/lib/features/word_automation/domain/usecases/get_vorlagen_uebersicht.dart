import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/word_automation/domain/entities/vorlagen_uebersicht.dart';
import 'package:automation_app/features/word_automation/domain/repositories/word_automation_repository.dart';
import 'package:injectable/injectable.dart';

/// Liefert den Vorlagenordner des Anwenders samt Inhalt.
///
/// Der Pfad wird bewusst beim Dienst erfragt statt im Frontend gebildet: er
/// zeigt nach `%APPDATA%\AutomationService\Vorlagen`, und diese Festlegung soll
/// an genau einer Stelle stehen.
@Injectable(as: UseCase<VorlagenUebersicht, NoParams>)
class GetVorlagenUebersicht implements UseCase<VorlagenUebersicht, NoParams> {
  final WordAutomationRepository repository;

  GetVorlagenUebersicht({required this.repository});

  @override
  Future<Either<Failure, VorlagenUebersicht>> call(NoParams params) =>
      repository.getVorlagenUebersicht();
}
