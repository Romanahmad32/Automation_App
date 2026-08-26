import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:equatable/equatable.dart';

/// Eine vom Postfach-Monitor automatisch erfasste Zentralruf-Antwort. Die
/// extrahierten Vorgangsdaten ([data]) sind dieselben wie beim manuellen
/// Einfügen — der Monitor schickt sie durch dieselbe Auswertung.
/// Spiegelt das Backend-DTO `ReceivedReplyDto`.
class ReceivedReply extends Equatable {
  /// Prozessweite Kennung des Treffers (zum Quittieren).
  final String id;

  final DateTime receivedAt;
  final String? subject;
  final String? from;

  /// True, wenn der Anwalt den Treffer als erledigt markiert hat.
  final bool acknowledged;

  final ZentralrufReplyData data;

  /// Hinweise auf mögliche Falschzuordnungen (z. B. Kennzeichen passt nicht
  /// zur Referenz, Negativ-Antwort) — identisch zur manuellen Auswertung.
  final List<String> warnings;

  /// Dateien, die an der Antwort hingen (§4.3) — beim Versand zum Anhängen
  /// angeboten. Der Anwalt zieht sie sonst im Mailprogramm von Hand aus der
  /// erhaltenen Nachricht in die ausgehende.
  final List<String> anhangPfade;

  /// Der aus der Mail gewonnene Rohtext, der durch den Parser lief. Fallback/
  /// Diagnose, falls das automatische Mapping unvollständig ist.
  final String? rawText;

  /// True, wenn das Backend den Vorgang nicht über die Referenz, sondern über
  /// den Fallback (Gegner-Kennzeichen + Unfalldatum) vermutet hat — eine vom
  /// Anwalt noch zu bestätigende Zuordnung.
  final bool zuordnungVermutet;

  const ReceivedReply({
    required this.id,
    required this.receivedAt,
    required this.subject,
    required this.from,
    required this.acknowledged,
    required this.data,
    required this.warnings,
    this.anhangPfade = const [],
    this.rawText,
    this.zuordnungVermutet = false,
  });

  factory ReceivedReply.fromJson(Map<String, dynamic> json) {
    return ReceivedReply(
      id: json['id'] as String,
      receivedAt:
          DateTime.tryParse(json['receivedAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      subject: json['subject'] as String?,
      from: json['from'] as String?,
      acknowledged: json['acknowledged'] as bool? ?? false,
      data: ZentralrufReplyData.fromJson(json['data'] as Map<String, dynamic>),
      warnings: List<String>.from(json['warnings'] as List? ?? const []),
      anhangPfade: List<String>.from(json['anhangPfade'] as List? ?? const []),
      rawText: json['rawText'] as String?,
      zuordnungVermutet: json['zuordnungVermutet'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    receivedAt,
    subject,
    from,
    acknowledged,
    data,
    warnings,
    anhangPfade,
    rawText,
    zuordnungVermutet,
  ];
}
