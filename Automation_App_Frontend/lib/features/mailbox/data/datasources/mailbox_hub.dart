import 'dart:async';

import 'package:automation_app/core/backend/backend_endpoint.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_push_notifier.dart';
import 'package:injectable/injectable.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Push-Anbindung an den Postfach-Monitor des Backends (`/hubs/mailbox`).
///
/// Das Backend sendet nutzdatenfreie Signale: `replyReceived`, sobald eine neue
/// Zentralruf-Antwort erfasst wurde, und `statusChanged` bei einem Wechsel des
/// Verbindungszustands. Die Oberfläche holt den konkreten Stand anschließend per
/// REST nach (siehe [MailboxInboxCubit]); so bleibt der Store die einzige
/// Datenquelle und die Signale müssen keine DTOs serialisieren.
///
/// Push ist best-effort: Schlägt der Verbindungsaufbau fehl, funktioniert die
/// Ansicht weiter über manuelles „Aktualisieren".
@LazySingleton(as: MailboxPushNotifier)
class MailboxHub implements MailboxPushNotifier {
  static const _url = BackendEndpoint.mailboxHubUrl;

  HubConnection? _connection;
  Future<void>? _starting;

  final _replyReceived = StreamController<void>.broadcast();
  final _statusChanged = StreamController<void>.broadcast();

  /// Feuert, sobald das Backend eine neu erfasste Antwort meldet.
  @override
  Stream<void> get onReplyReceived => _replyReceived.stream;

  /// Feuert, sobald sich der Verbindungsstatus der Überwachung ändert.
  @override
  Stream<void> get onStatusChanged => _statusChanged.stream;

  /// Baut die Verbindung einmalig auf (idempotent). Mehrfachaufrufe teilen sich
  /// denselben laufenden Verbindungsaufbau.
  @override
  Future<void> ensureConnected() {
    if (_connection != null) return Future.value();
    return _starting ??= _connect();
  }

  Future<void> _connect() async {
    final connection = HubConnectionBuilder()
        .withUrl(_url)
        .withAutomaticReconnect()
        .build();

    connection.on('replyReceived', (_) {
      if (!_replyReceived.isClosed) _replyReceived.add(null);
    });
    connection.on('statusChanged', (_) {
      if (!_statusChanged.isClosed) _statusChanged.add(null);
    });

    try {
      await connection.start();
      _connection = connection;
    } catch (_) {
      // Best-effort: ohne Push bleibt die Ansicht über manuelles Aktualisieren nutzbar.
      _starting = null;
    }
  }

  @override
  @disposeMethod
  Future<void> dispose() async {
    await _connection?.stop();
    await _replyReceived.close();
    await _statusChanged.close();
  }
}
