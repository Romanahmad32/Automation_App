import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:equatable/equatable.dart';

/// Ob die App senden kann und von welcher Adresse aus (§4.7). Wird abgefragt,
/// **bevor** der Anwalt zu tippen beginnt — einen fertigen Text an einer
/// fehlenden Anmeldung scheitern zu lassen, ist die teuerste Art, das zu
/// erfahren.
class EmailVersandBereitschaft extends Equatable {
  final bool bereit;
  final String absender;

  /// Grund im Klartext, wenn nicht bereit; sonst null.
  final String? hinweis;

  /// Der Signaturblock aus den Einstellungen, den der Direktversand anfügt.
  /// Nur zum Anzeigen in der Vorschau — geändert wird er in den Einstellungen.
  final String signatur;

  /// Die Bilder der formatierten Signatur mit ihrer Größe. Der Anwalt lässt
  /// einzelne davon je Mail weg — das schwere Werbebild etwa —, und dafür muss
  /// er sehen, was sie wiegen.
  final List<SignaturBild> signaturBilder;

  /// Obergrenze der ganzen Nachricht in MB, wie der Dienst sie prüft. Sie steht
  /// hier, damit die Oberfläche beim Anhängen mitzählen kann: Die Grenze erst
  /// beim Senden zu nennen, hieße sie nach dem einen unumkehrbaren Klick zu
  /// nennen. 0 heißt: noch nicht abgefragt.
  final int maxAnhangMb;

  const EmailVersandBereitschaft({
    required this.bereit,
    this.absender = '',
    this.hinweis,
    this.signatur = '',
    this.signaturBilder = const [],
    this.maxAnhangMb = 0,
  });

  factory EmailVersandBereitschaft.fromJson(Map<String, dynamic> json) {
    return EmailVersandBereitschaft(
      bereit: json['bereit'] as bool? ?? false,
      absender: json['absender'] as String? ?? '',
      hinweis: json['hinweis'] as String?,
      signatur: json['signatur'] as String? ?? '',
      signaturBilder: [
        for (final bild in (json['signaturBilder'] as List?) ?? const [])
          SignaturBild.fromJson(bild as Map<String, dynamic>),
      ],
      maxAnhangMb: (json['maxAnhangMb'] as num?)?.toInt() ?? 0,
    );
  }

  /// Die Grenze in Bytes; null, solange sie nicht bekannt ist.
  int? get maxBytes => maxAnhangMb > 0 ? maxAnhangMb * 1024 * 1024 : null;

  @override
  List<Object?> get props => [
    bereit,
    absender,
    hinweis,
    signatur,
    signaturBilder,
    maxAnhangMb,
  ];
}
