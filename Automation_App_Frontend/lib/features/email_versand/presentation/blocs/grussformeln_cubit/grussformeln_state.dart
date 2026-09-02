import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';
import 'package:equatable/equatable.dart';

/// Stand des Grußformel-Bestands (§4.7). Ein Zustand statt einer
/// Zustandsfamilie, aus demselben Grund wie beim Vorlagenbestand: Die Liste
/// bleibt beim Laden und nach einem Fehler stehen.
class GrussformelnState extends Equatable {
  final List<Grussformel> grussformeln;
  final bool laedt;
  final String? fehler;

  /// Trennt „noch keiner angelegt" von „noch nicht nachgesehen".
  final bool geladen;

  const GrussformelnState({
    this.grussformeln = const [],
    this.laedt = false,
    this.fehler,
    this.geladen = false,
  });

  GrussformelnState kopie({
    List<Grussformel>? grussformeln,
    bool? laedt,
    String? fehler,
    bool? geladen,
  }) => GrussformelnState(
    grussformeln: grussformeln ?? this.grussformeln,
    laedt: laedt ?? this.laedt,
    // Bewusst ohne Rückfall: Ein neuer Versuch soll die alte Meldung loswerden.
    fehler: fehler,
    geladen: geladen ?? this.geladen,
  );

  @override
  List<Object?> get props => [grussformeln, laedt, fehler, geladen];
}
