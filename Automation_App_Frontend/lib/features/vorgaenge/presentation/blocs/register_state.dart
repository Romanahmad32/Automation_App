import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_reihenfolge.dart';
import 'package:equatable/equatable.dart';

/// Was die Registerseite zeigt: die Zeilen aus dem Backend, der Stand der
/// übernommenen Historie und die Auswahl darüber.
class RegisterState extends Equatable {
  /// Alle Zeilen, ungefiltert und in der Reihenfolge des Backends.
  final List<RegisterZeile> zeilen;

  final RegisterHistorieStand stand;

  final RegisterFilter filter;

  /// In welcher Richtung gelesen wird. Neben dem Filter und nicht in ihm: Der
  /// Filter entscheidet, *welche* Zeilen zu sehen sind, die Reihenfolge nur, in
  /// welcher Folge — und sie überlebt ein „Filter zurücksetzen".
  final RegisterReihenfolge reihenfolge;

  /// Ob gerade geladen wird — beim Öffnen der Seite und nach einer
  /// Berichtigung.
  final bool laedt;

  /// Klartext, wenn der Dienst nicht erreichbar war. Null sonst.
  final String? fehler;

  const RegisterState({
    this.zeilen = const [],
    this.stand = RegisterHistorieStand.leer,
    this.filter = RegisterFilter.alle,
    this.reihenfolge = RegisterReihenfolge.vorgabe,
    this.laedt = false,
    this.fehler,
  });

  /// Die sichtbaren Zeilen, gefiltert und in Leserichtung. Gerechnet statt
  /// mitgeführt: Filter und Reihenfolge ändern sich häufiger als der Bestand,
  /// und zwei Listen im Zustand liefen sonst auseinander.
  List<RegisterZeile> get sichtbar =>
      reihenfolge.anwenden(filter.anwenden(zeilen));

  RegisterState copyWith({
    List<RegisterZeile>? zeilen,
    RegisterHistorieStand? stand,
    RegisterFilter? filter,
    RegisterReihenfolge? reihenfolge,
    bool? laedt,
    String? fehler,
    bool fehlerLoeschen = false,
  }) => RegisterState(
    zeilen: zeilen ?? this.zeilen,
    stand: stand ?? this.stand,
    filter: filter ?? this.filter,
    reihenfolge: reihenfolge ?? this.reihenfolge,
    laedt: laedt ?? this.laedt,
    fehler: fehlerLoeschen ? null : fehler ?? this.fehler,
  );

  @override
  List<Object?> get props => [
    zeilen,
    stand,
    filter,
    reihenfolge,
    laedt,
    fehler,
  ];
}
