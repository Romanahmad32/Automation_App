import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';

/// Liefert einen festen Kanzlei-Stand, ohne Backend.
///
/// Stand vormals wortgleich in vier Testdateien (Kanzleidaten, Signatur
/// anzeigen, Signatur speichern, Postfach-Zugang). Vier Kopien heißen: Wer
/// [UseCase] ein Mitglied hinzufügt, repariert viermal dasselbe — und stößt auf
/// die vierte Kopie erst, wenn sie rot wird.
class FesterSettingsAbruf implements UseCase<KanzleiSettings, NoParams> {
  final KanzleiSettings stand;

  FesterSettingsAbruf(this.stand);

  @override
  Future<Either<Failure, KanzleiSettings>> call(NoParams params) async =>
      Right(stand);
}

/// Nimmt entgegen, was gespeichert wird, und gibt es unverändert zurück.
///
/// Für Tests, die nur das Anzeigen prüfen. Wer wissen muss, **was** gespeichert
/// wurde, baut ein mitschreibendes Double in seiner eigenen Testdatei — so wie
/// `mail_signatur_speichern_test.dart`.
class DurchreichendesSpeichern
    implements UseCase<KanzleiSettings, KanzleiSettings> {
  @override
  Future<Either<Failure, KanzleiSettings>> call(KanzleiSettings params) async =>
      Right(params);
}
