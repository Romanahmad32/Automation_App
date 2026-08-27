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

  const SignaturBild({required this.dateiname, required this.bytes});

  factory SignaturBild.fromJson(Map<String, dynamic> json) => SignaturBild(
    dateiname: json['dateiname'] as String? ?? '',
    bytes: (json['bytes'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [dateiname, bytes];
}
