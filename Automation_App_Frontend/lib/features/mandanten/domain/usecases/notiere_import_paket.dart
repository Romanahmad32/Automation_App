import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart';
import 'package:injectable/injectable.dart';

/// Verbucht ein herausgegebenes Arbeitspaket. Das Backend vergibt dabei die
/// Nummer und merkt sich die Ordnernamen — daraus rechnet es später aus,
/// welche eingelesene Datei welches Paket abschließt.
///
/// **Reihenfolge:** erst die Datei speichern lassen, dann verbuchen. Bricht der
/// Anwalt den Speichern-Dialog ab, ist nichts herausgegangen, und eine Nummer
/// wäre vergeben für ein Paket, das niemand hat.
@Injectable(as: UseCase<ImportPaket, NotiereImportPaketParams>)
class NotiereImportPaket
    implements UseCase<ImportPaket, NotiereImportPaketParams> {
  final MandantenRepository _repository;

  NotiereImportPaket(this._repository);

  @override
  Future<Either<Failure, ImportPaket>> call(NotiereImportPaketParams params) {
    return _repository.notiereImportPaket(params.ordnernamen);
  }
}

class NotiereImportPaketParams {
  /// Die Ordnernamen des Pakets — `Arbeitspaket.ordnernamen`.
  final List<String> ordnernamen;

  const NotiereImportPaketParams({required this.ordnernamen});
}
