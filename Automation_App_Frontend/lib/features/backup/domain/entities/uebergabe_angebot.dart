import 'package:equatable/equatable.dart';

/// Der Arbeitsplatz, dessen Stand zur Übernahme bereitliegt (§7.2).
///
/// Die beiden Zeitpunkte sind bewusst getrennt: [zuletztGearbeitet] steht im
/// Satz auf dem Bildschirm („Zuletzt heute 14:12 auf BUERO-PC gearbeitet"),
/// [gesichertAm] ist der Stand, der tatsächlich übernommen würde. Wer beide
/// zusammenlegt, macht aus einem Rechner, der heute nur kurz auf war, den
/// „neueren" Stand — obwohl sein Archiv von vorgestern ist.
class UebergabeAngebot extends Equatable {
  final String rechnername;
  final DateTime zuletztGearbeitet;
  final DateTime gesichertAm;

  /// Dateiname des Archivs im Ablageordner.
  final String sicherung;

  /// Fassung, die den Stand geschrieben hat.
  final String programmfassung;

  const UebergabeAngebot({
    required this.rechnername,
    required this.zuletztGearbeitet,
    required this.gesichertAm,
    required this.sicherung,
    required this.programmfassung,
  });

  factory UebergabeAngebot.fromJson(
    Map<String, dynamic> json,
  ) => UebergabeAngebot(
    rechnername: json['rechnername'] as String? ?? '',
    // `toLocal()`: der Dienst sendet mit Zeitzonenversatz, angezeigt wird Ortszeit.
    zuletztGearbeitet:
        DateTime.tryParse(
          json['zuletztGearbeitet'] as String? ?? '',
        )?.toLocal() ??
        DateTime.now(),
    gesichertAm:
        DateTime.tryParse(json['gesichertAm'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    sicherung: json['sicherung'] as String? ?? '',
    programmfassung: json['programmfassung'] as String? ?? '',
  );

  @override
  List<Object?> get props => [
    rechnername,
    zuletztGearbeitet,
    gesichertAm,
    sicherung,
    programmfassung,
  ];
}
