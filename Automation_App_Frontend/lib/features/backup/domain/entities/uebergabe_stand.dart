import 'package:automation_app/features/backup/domain/entities/letzte_sicherung.dart';
import 'package:automation_app/features/backup/domain/entities/uebergabe_angebot.dart';
import 'package:equatable/equatable.dart';

/// Was der Start über die Sicherungsablage wissen muss (§7.2) — beides in einer
/// Auskunft, weil beides an derselben Stelle gezeigt wird: die Frage nach der
/// Übernahme und die Meldung über eine misslungene Sicherung.
class UebergabeStand extends Equatable {
  /// Der übernehmbare fremde Stand, sonst null.
  final UebergabeAngebot? angebot;

  /// Wann dieser Rechner zuletzt gesichert hat; null heißt: noch nie. Steht
  /// neben dem Angebot, damit sichtbar ist, *was* ersetzt würde — ein Angebot
  /// ohne diesen Vergleich wäre eine Frage ohne die Hälfte der Antwort.
  final DateTime? eigenerStandGesichertAm;

  final LetzteSicherung? letzteSicherung;

  /// Der eingestellte Ablageordner; leer heißt: automatische Sicherung aus.
  final String ablageOrdner;

  /// Anzahl der Archive dieses Rechners in der Ablage (§7.2).
  final int eigeneArchive;

  /// Zeitpunkt des ältesten eigenen Archivs; null ohne eigene Archive.
  final DateTime? aeltestesArchiv;

  const UebergabeStand({
    this.angebot,
    this.eigenerStandGesichertAm,
    this.letzteSicherung,
    this.ablageOrdner = '',
    this.eigeneArchive = 0,
    this.aeltestesArchiv,
  });

  /// Nichts anzuzeigen — der Start geht ohne Zwischenbild weiter.
  static const UebergabeStand still = UebergabeStand();

  /// Ob der Start überhaupt etwas zeigen muss.
  bool get brauchtRueckfrage =>
      angebot != null || (letzteSicherung?.offenerFehler ?? false);

  factory UebergabeStand.fromJson(Map<String, dynamic> json) {
    final angebot = json['angebot'] as Map<String, dynamic>?;
    final lauf = json['letzteSicherung'] as Map<String, dynamic>?;
    return UebergabeStand(
      angebot: angebot == null ? null : UebergabeAngebot.fromJson(angebot),
      // `toLocal()`: der Dienst sendet mit Zeitzonenversatz, angezeigt wird Ortszeit.
      eigenerStandGesichertAm: DateTime.tryParse(
        json['eigenerStandGesichertAm'] as String? ?? '',
      )?.toLocal(),
      letzteSicherung: lauf == null ? null : LetzteSicherung.fromJson(lauf),
      ablageOrdner: json['ablageOrdner'] as String? ?? '',
      eigeneArchive: json['eigeneArchive'] as int? ?? 0,
      aeltestesArchiv: DateTime.tryParse(
        json['aeltestesArchiv'] as String? ?? '',
      )?.toLocal(),
    );
  }

  @override
  List<Object?> get props => [
    angebot,
    eigenerStandGesichertAm,
    letzteSicherung,
    ablageOrdner,
    eigeneArchive,
    aeltestesArchiv,
  ];
}
