import 'package:equatable/equatable.dart';

/// Verbindungszustand der Postfach-Überwachung, wie ihn die Inbox-Ansicht oben
/// anzeigt. Spiegelt das Backend-DTO `MailboxStatusDto`.
class MailboxStatus extends Equatable {
  final bool enabled;
  final bool configured;
  final bool connected;
  final bool idleSupported;
  final DateTime? lastConnectedAt;
  final DateTime? lastReplyAt;
  final String? lastError;

  /// Insgesamt erfasste Antworten seit App-Start.
  final int receivedCount;

  /// Noch nicht quittierte Antworten.
  final int pendingCount;

  const MailboxStatus({
    required this.enabled,
    required this.configured,
    required this.connected,
    required this.idleSupported,
    required this.lastConnectedAt,
    required this.lastReplyAt,
    required this.lastError,
    required this.receivedCount,
    required this.pendingCount,
  });

  static const MailboxStatus unknown = MailboxStatus(
    enabled: false,
    configured: false,
    connected: false,
    idleSupported: false,
    lastConnectedAt: null,
    lastReplyAt: null,
    lastError: null,
    receivedCount: 0,
    pendingCount: 0,
  );

  factory MailboxStatus.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;

    return MailboxStatus(
      enabled: json['enabled'] as bool? ?? false,
      configured: json['configured'] as bool? ?? false,
      connected: json['connected'] as bool? ?? false,
      idleSupported: json['idleSupported'] as bool? ?? false,
      lastConnectedAt: parseDate(json['lastConnectedAt']),
      lastReplyAt: parseDate(json['lastReplyAt']),
      lastError: json['lastError'] as String?,
      receivedCount: (json['receivedCount'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    enabled,
    configured,
    connected,
    idleSupported,
    lastConnectedAt,
    lastReplyAt,
    lastError,
    receivedCount,
    pendingCount,
  ];
}
