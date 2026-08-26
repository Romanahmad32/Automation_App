import 'package:equatable/equatable.dart';

/// Eine im Mailprogramm eingerichtete Signatur (§4.7). Der [name] ist der, unter
/// dem sie in Outlook steht — eine Kanzlei hat oft mehrere („Kurz",
/// „Vollständig"), und welche gemeint ist, kann nur der Anwalt sagen.
class OutlookSignatur extends Equatable {
  final String name;
  final String text;

  const OutlookSignatur({required this.name, required this.text});

  factory OutlookSignatur.fromJson(Map<String, dynamic> json) {
    return OutlookSignatur(
      name: json['name'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }

  /// Die ersten Zeilen, um sie in der Auswahl auseinanderzuhalten.
  String get vorschau {
    final zeilen = text
        .split('\n')
        .map((zeile) => zeile.trim())
        .where((zeile) => zeile.isNotEmpty)
        .take(2);
    return zeilen.join(' · ');
  }

  @override
  List<Object?> get props => [name, text];
}
