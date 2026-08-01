import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mailbox/data/datasources/mailbox_datasource.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_repository.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

@Injectable(as: MailboxRepository)
class MailboxRepositoryImpl implements MailboxRepository {
  final MailboxDatasource _datasource;

  MailboxRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, MailboxConfig>> getConfig() =>
      _guard(() => _datasource.getConfig());

  @override
  Future<Either<Failure, MailboxConfig>> saveConfig(
    MailboxConfigUpdate update,
  ) => _guard(() => _datasource.saveConfig(update));

  @override
  Future<Either<Failure, MailboxConfig>> microsoftSignIn() =>
      _guard(() => _datasource.microsoftSignIn());

  @override
  Future<Either<Failure, MailboxConfig>> microsoftSignOut() =>
      _guard(() => _datasource.microsoftSignOut());

  @override
  Future<Either<Failure, MailboxStatus>> getStatus() =>
      _guard(() => _datasource.getStatus());

  @override
  Future<Either<Failure, List<ReceivedReply>>> getReplies({
    bool includeAcknowledged = false,
  }) => _guard(
    () => _datasource.getReplies(includeAcknowledged: includeAcknowledged),
  );

  @override
  Future<Either<Failure, void>> acknowledge(String id) =>
      _guard(() => _datasource.acknowledge(id));

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (e) {
      // Das Backend läuft lokal; ein Verbindungsfehler heißt meist, dass der
      // Dienst (noch) nicht gestartet ist. Fehlerantworten des Backends kommen
      // als ProblemDetails — deren Klartext (z. B. "Microsoft-Anmeldung
      // fehlgeschlagen") ist für den Nutzer hilfreicher als der Dio-Wortlaut.
      final problem = e.response?.data;
      final detail = problem is Map<String, dynamic>
          ? (problem['detail'] as String? ?? problem['title'] as String?)
          : null;
      final message = e.type == DioExceptionType.connectionError
          ? 'Keine Verbindung zum lokalen Dienst (localhost:5143).'
          : detail ?? 'Der Dienst hat die Anfrage abgelehnt: ${e.message}';
      return Left(ServerFailure(message: message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
