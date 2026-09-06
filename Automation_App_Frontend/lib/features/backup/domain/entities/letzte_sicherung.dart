import 'package:equatable/equatable.dart';

/// Ausgang des letzten automatischen Sicherungslaufs (§7.2).
///
/// Der Lauf passiert, wenn das Fenster schon zu ist — es gibt in dem Moment
/// niemanden, dem man etwas sagen könnte. Deshalb hebt das Backend das Ergebnis
/// auf, und die App zeigt es beim nächsten Start. Ohne das wäre eine Sicherung,
/// die seit Wochen an einem umbenannten Ordner scheitert, nicht von einer
/// heilen zu unterscheiden — bis der Anwalt sie braucht.
class LetzteSicherung extends Equatable {
  final DateTime zeitpunkt;
  final bool gelungen;

  /// Name des Archivs, wenn der Lauf gelungen ist.
  final String? datei;

  /// Was schiefging, in Worten, die der Anwalt lesen kann.
  final String? meldung;

  /// Ob die Meldung schon gezeigt und weggeklickt wurde.
  final bool fehlerQuittiert;

  const LetzteSicherung({
    required this.zeitpunkt,
    required this.gelungen,
    this.datei,
    this.meldung,
    this.fehlerQuittiert = false,
  });

  /// Ein Fehlschlag, der dem Anwalt noch gezeigt werden muss.
  bool get offenerFehler => !gelungen && !fehlerQuittiert;

  factory LetzteSicherung.fromJson(
    Map<String, dynamic> json,
  ) => LetzteSicherung(
    // Der Dienst sendet den Zeitpunkt mit Zeitzonenversatz; ohne
    // `toLocal()` stünde in der Anzeige die UTC-Uhrzeit (zwei Stunden früher).
    zeitpunkt:
        DateTime.tryParse(json['zeitpunkt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    gelungen: json['gelungen'] as bool? ?? false,
    datei: json['datei'] as String?,
    meldung: json['meldung'] as String?,
    fehlerQuittiert: json['fehlerQuittiert'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    zeitpunkt,
    gelungen,
    datei,
    meldung,
    fehlerQuittiert,
  ];
}
