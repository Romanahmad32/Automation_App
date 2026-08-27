import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:equatable/equatable.dart';

/// Die Signatur, wie sie nach einer Übernahme in den Einstellungen liegt
/// (§4.7).
///
/// Die HTML-Fassung selbst kommt nicht mit: Sie ist zehntausende Zeichen groß,
/// die App zeigt sie nicht an und kann sie nicht bearbeiten. Was hier zählt,
/// ist, **dass** es eine formatierte Fassung gibt und welche Bilder darin
/// stecken — beides muss der Anwalt sehen, bevor er sendet.
class SignaturStand extends Equatable {
  final String text;
  final bool hatFormat;
  final List<SignaturBild> bilder;

  const SignaturStand({
    this.text = '',
    this.hatFormat = false,
    this.bilder = const [],
  });

  factory SignaturStand.fromJson(Map<String, dynamic> json) => SignaturStand(
    text: json['text'] as String? ?? '',
    hatFormat: json['hatFormat'] as bool? ?? false,
    bilder: [
      for (final bild in (json['bilder'] as List?) ?? const [])
        SignaturBild.fromJson(bild as Map<String, dynamic>),
    ],
  );

  int get bilderBytes => bilder.fold(0, (summe, bild) => summe + bild.bytes);

  @override
  List<Object?> get props => [text, hatFormat, bilder];
}
