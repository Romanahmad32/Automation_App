import 'package:equatable/equatable.dart';

/// Ein Bild, das in der formatierten Signatur steckt: Kanzleilogo,
/// Zertifikatssiegel, das animierte Werbebild (§4.7).
///
/// Die Größe steht dabei, weil genau sie die Frage entscheidet, die der Anwalt
/// je Mail beantwortet: Ein paar Kilobyte Logo gehen immer mit, ein GIF von
/// mehreren Megabyte nicht unter jede Nachricht.
class SignaturBild extends Equatable {
  final String dateiname;
  final int bytes;

  /// Der Inhalt des Bildes in Kurzform, wie der Dienst ihn meldet — gehört an
  /// die Adresse, unter der die Vorschau es lädt.
  ///
  /// Der Name allein taugt dafür nicht: Outlook nennt das erste Bild **jeder**
  /// Signatur `image001.png`. Flutter hebt geladene Bilder je Adresse auf, und
  /// weil die sich beim Signaturwechsel nicht änderte, zeigte die Vorschau
  /// weiter das Logo der vorigen — bis zum Neustart der App (behoben am
  /// 04.09.2026). Leer heißt: Der Dienst konnte sie nicht bilden; dann bleibt
  /// es beim alten Verhalten.
  final String marke;

  const SignaturBild({
    required this.dateiname,
    required this.bytes,
    this.marke = '',
  });

  factory SignaturBild.fromJson(Map<String, dynamic> json) => SignaturBild(
    dateiname: json['dateiname'] as String? ?? '',
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    marke: json['marke'] as String? ?? '',
  );

  @override
  List<Object?> get props => [dateiname, bytes, marke];
}
