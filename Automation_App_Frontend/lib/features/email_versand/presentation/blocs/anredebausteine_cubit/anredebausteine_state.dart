import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';
import 'package:equatable/equatable.dart';

/// Stand des Anredebestands (§4.7). Ein Zustand statt einer Zustandsfamilie,
/// aus demselben Grund wie beim Grußformel-Bestand: Die Liste bleibt beim Laden
/// und nach einem Fehler stehen.
class AnredebausteineState extends Equatable {
  final List<Anredebaustein> bausteine;
  final bool laedt;
  final String? fehler;

  /// Trennt „noch keiner angelegt" von „noch nicht nachgesehen".
  final bool geladen;

  const AnredebausteineState({
    this.bausteine = const [],
    this.laedt = false,
    this.fehler,
    this.geladen = false,
  });

  /// Der Anfang, der ohne Wahl gilt: der erste der Liste. Die Reihenfolge legt
  /// der Bestand fest, und an erster Stelle steht ab Werk „Sehr geehrter" —
  /// also genau die Anrede, die die App vorher fest erzeugt hat.
  Anredebaustein? get vorgabe => bausteine.firstOrNull;

  Anredebaustein? zuId(int id) =>
      bausteine.where((baustein) => baustein.id == id).firstOrNull;

  AnredebausteineState kopie({
    List<Anredebaustein>? bausteine,
    bool? laedt,
    String? fehler,
    bool? geladen,
  }) => AnredebausteineState(
    bausteine: bausteine ?? this.bausteine,
    laedt: laedt ?? this.laedt,
    // Bewusst ohne Rückfall: Ein neuer Versuch soll die alte Meldung loswerden.
    fehler: fehler,
    geladen: geladen ?? this.geladen,
  );

  @override
  List<Object?> get props => [bausteine, laedt, fehler, geladen];
}
