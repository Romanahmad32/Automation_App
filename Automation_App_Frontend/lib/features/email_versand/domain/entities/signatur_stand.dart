import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:equatable/equatable.dart';

/// Die Signatur, wie sie nach einer Übernahme in den Einstellungen liegt
/// (§4.7).
///
/// Die HTML-Fassung kommt **mit** — zum Anzeigen, nicht zum Bearbeiten. Ohne
/// sie zeigte die Vorschau Outlooks Nur-Text-Übersetzung und damit etwas
/// anderes, als beim Empfänger ankommt. Groß ist sie nicht: Die zehntausende
/// Zeichen sind die ganze Outlook-Datei mit Word-Stilvorlage, der versendete
/// Rumpf sind wenige Kilobyte.
class SignaturStand extends Equatable {
  final String text;
  final bool hatFormat;

  /// Die formatierte Fassung, wie sie in die Mail geht; leer ohne Übernahme.
  final String html;

  final List<SignaturBild> bilder;

  /// Bilder, die beim Übernehmen **nicht** mitgenommen werden konnten — zu
  /// groß, leer oder nicht lesbar. Ihre Bildmarken sind aus der Signatur
  /// entfernt, damit beim Empfänger kein Platzhalterkreuz steht; hier stehen
  /// sie, damit der Anwalt erfährt, was fehlt. Beim bloßen Abfragen des
  /// Stands immer leer.
  final List<String> uebergangen;

  const SignaturStand({
    this.text = '',
    this.hatFormat = false,
    this.html = '',
    this.bilder = const [],
    this.uebergangen = const [],
  });

  factory SignaturStand.fromJson(Map<String, dynamic> json) => SignaturStand(
    text: json['text'] as String? ?? '',
    hatFormat: json['hatFormat'] as bool? ?? false,
    html: json['html'] as String? ?? '',
    bilder: [
      for (final bild in (json['bilder'] as List?) ?? const [])
        SignaturBild.fromJson(bild as Map<String, dynamic>),
    ],
    uebergangen: [
      for (final name in (json['uebergangen'] as List?) ?? const [])
        name as String,
    ],
  );

  int get bilderBytes => bilder.fold(0, (summe, bild) => summe + bild.bytes);

  @override
  List<Object?> get props => [text, hatFormat, html, bilder, uebergangen];
}
