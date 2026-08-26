import 'package:equatable/equatable.dart';

/// Die Mail, wie der Anwalt sie gerade verfasst (§4.7). Reiner Zustand ohne
/// Versandlogik — dieselbe Form geht am Ende an das Backend.
class EmailEntwurf extends Equatable {
  final List<String> an;
  final List<String> kopie;
  final String betreff;
  final String text;

  /// Vollständige Pfade der Anhänge. Dienst und Oberfläche laufen auf einem
  /// Rechner; der Weg über Pfade erspart es, jede Datei durch die
  /// HTTP-Schnittstelle zu schieben (wie bei der Ablage in der Akte).
  final List<String> anhangPfade;

  /// Abweichender Dateiname je Anhangpfad, wenn der Anwalt umbenannt hat.
  /// Die Datei in der Akte behält ihren Namen — geändert wird nur, was beim
  /// Empfänger ankommt: „Dokument1.pdf" sagt dort niemandem etwas.
  final Map<String, String> anhangNamen;

  const EmailEntwurf({
    this.an = const [],
    this.kopie = const [],
    this.betreff = '',
    this.text = '',
    this.anhangPfade = const [],
    this.anhangNamen = const {},
  });

  /// Ohne Empfänger und ohne Betreff wird nicht gesendet. Der Text darf leer
  /// sein — ein Anschreiben, das nur aus dem Anhang besteht, ist zulässig.
  bool get istSendbar => an.isNotEmpty && betreff.trim().isNotEmpty;

  /// Alle angeschriebenen Adressen, für Rückfrage und Zusammenfassung.
  List<String> get alleEmpfaenger => [...an, ...kopie];

  EmailEntwurf copyWith({
    List<String>? an,
    List<String>? kopie,
    String? betreff,
    String? text,
    List<String>? anhangPfade,
    Map<String, String>? anhangNamen,
  }) {
    return EmailEntwurf(
      an: an ?? this.an,
      kopie: kopie ?? this.kopie,
      betreff: betreff ?? this.betreff,
      text: text ?? this.text,
      anhangPfade: anhangPfade ?? this.anhangPfade,
      anhangNamen: anhangNamen ?? this.anhangNamen,
    );
  }

  Map<String, dynamic> toJson(String absenderName) => {
    'an': an,
    'kopie': kopie,
    'betreff': betreff,
    'text': text,
    'anhangPfade': anhangPfade,
    'anhangNamen': anhangNamen,
    'absenderName': absenderName,
  };

  /// Der Name, unter dem ein Anhang hinausgeht: der umbenannte, sonst der
  /// Dateiname auf Platte.
  String nameVon(String pfad) =>
      anhangNamen[pfad] ?? pfad.split(RegExp('[\\\\/]')).last;

  @override
  List<Object?> get props => [
    an,
    kopie,
    betreff,
    text,
    anhangPfade,
    anhangNamen,
  ];
}
