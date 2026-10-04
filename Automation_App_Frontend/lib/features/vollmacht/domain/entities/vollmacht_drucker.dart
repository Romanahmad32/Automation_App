import 'package:equatable/equatable.dart';

/// Was Windows über den Standarddrucker meldet — die Werte des Feldes
/// `zustand` im `VollmachtDruckerDto`.
enum VollmachtDruckerZustand {
  bereit('bereit'),
  offline('offline'),
  gestoert('gestoert'),
  angehalten('angehalten'),
  keinDrucker('keinDrucker'),
  unbekannt('unbekannt');

  final String wert;

  const VollmachtDruckerZustand(this.wert);

  /// Ein unbekannter Wert ist [unbekannt] — nie still „bereit".
  static VollmachtDruckerZustand ausWert(String? wert) {
    for (final zustand in values) {
      if (zustand.wert == wert) return zustand;
    }
    return unbekannt;
  }
}

/// Der Drucker, an den „Drucken" geht (§4.11): der Windows-Standarddrucker.
/// Der Zustand ist ein Hinweis, keine Sperre — viele Drucker melden sich auch
/// offline als bereit. Gesperrt wird nur, wenn gar keiner eingerichtet ist.
class VollmachtDrucker extends Equatable {
  /// Null bei [VollmachtDruckerZustand.keinDrucker].
  final String? name;
  final VollmachtDruckerZustand zustand;

  /// Was los ist, in Worten; null bei [VollmachtDruckerZustand.bereit].
  final String? hinweis;

  const VollmachtDrucker({this.name, required this.zustand, this.hinweis});

  /// Ob „Drucken" überhaupt möglich ist.
  bool get kannDrucken => zustand != VollmachtDruckerZustand.keinDrucker;

  factory VollmachtDrucker.fromJson(Map<String, dynamic> json) =>
      VollmachtDrucker(
        name: json['name'] as String?,
        zustand: VollmachtDruckerZustand.ausWert(json['zustand'] as String?),
        hinweis: json['hinweis'] as String?,
      );

  @override
  List<Object?> get props => [name, zustand, hinweis];
}
