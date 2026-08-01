import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';

/// Zugriff auf die Postfach-Überwachung des Backends: Zugang lesen/speichern,
/// Verbindungsstatus abfragen und die erfassten Antworten abrufen/quittieren.
abstract class MailboxRepository {
  Future<Either<Failure, MailboxConfig>> getConfig();

  Future<Either<Failure, MailboxConfig>> saveConfig(MailboxConfigUpdate update);

  /// Microsoft-Anmeldung für Outlook-Postfächer (Browser öffnet sich am Backend).
  Future<Either<Failure, MailboxConfig>> microsoftSignIn();

  Future<Either<Failure, MailboxConfig>> microsoftSignOut();

  Future<Either<Failure, MailboxStatus>> getStatus();

  Future<Either<Failure, List<ReceivedReply>>> getReplies({
    bool includeAcknowledged,
  });

  Future<Either<Failure, void>> acknowledge(String id);
}
