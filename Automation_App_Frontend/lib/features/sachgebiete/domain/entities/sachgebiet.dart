import 'package:equatable/equatable.dart';

/// Ein Eintrag des Sachgebietskatalogs der Kanzlei (§7.1): Abteilungskürzel
/// plus Sachgebiet, wie sie im Kopf des gewachsenen Registers stehen.
/// Spiegelt das Backend-DTO `SachgebietDto` (`GET /api/Sachgebiete`).
///
/// Der Katalog ist die Quelle der Auswahllisten für Abteilung (§4.2) und
/// Rechtsgebiet (§6.2) — bewusst breiter als der Aktenbestand, damit auch
/// selten genutzte Abteilungen wählbar bleiben.
class Sachgebiet extends Equatable {
  final int id;

  /// Abteilungskürzel, z. B. "C03o" — nie leer, nie mit Leerzeichen (§7.1).
  final String kuerzel;

  /// Name des Sachgebiets, z. B. "Zivilrecht (allgemein)".
  final String name;

  /// Vorschlag für die Sachgebietsspalte des Registers — meist gleich [name],
  /// ohne dessen Zusätze ("Zivilrecht (allgemein)" → "Zivilrecht").
  final String rechtsgebietVorschlag;

  /// Reihenfolge in Auswahllisten — Katalogreihenfolge, nicht alphabetisch.
  final int sortierung;

  /// Inaktive Einträge verschwinden aus der Auswahl, bleiben aber für den
  /// Bestand lesbar (Vorarbeit für die Katalogpflege, §7.1 [S]).
  final bool aktiv;

  const Sachgebiet({
    required this.id,
    required this.kuerzel,
    required this.name,
    required this.rechtsgebietVorschlag,
    required this.sortierung,
    required this.aktiv,
  });

  factory Sachgebiet.fromJson(Map<String, dynamic> json) => Sachgebiet(
    id: json['id'] as int,
    kuerzel: json['kuerzel'] as String,
    name: json['name'] as String,
    rechtsgebietVorschlag: json['rechtsgebietVorschlag'] as String,
    sortierung: json['sortierung'] as int,
    aktiv: json['aktiv'] as bool,
  );

  @override
  List<Object?> get props => [
    id,
    kuerzel,
    name,
    rechtsgebietVorschlag,
    sortierung,
    aktiv,
  ];
}
