import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:equatable/equatable.dart';

/// Ladezustand des Sachgebietskatalogs. Anders als beim `VersichererCubit`
/// ist ein Ladefehler hier **nicht** still zu schlucken: Ohne Katalog haben
/// die Auswahllisten für Rechtsgebiet und Abteilung keine Quelle, und eine
/// stillschweigend leere Auswahl sähe aus wie eine funktionierende (§7.1 —
/// genau die Fehlerklasse, die der Katalog beseitigt).
sealed class SachgebietKatalogStand extends Equatable {
  const SachgebietKatalogStand();

  @override
  List<Object?> get props => const [];
}

class SachgebietKatalogLaedt extends SachgebietKatalogStand {
  const SachgebietKatalogLaedt();
}

class SachgebietKatalogGeladen extends SachgebietKatalogStand {
  final List<Sachgebiet> eintraege;

  const SachgebietKatalogGeladen(this.eintraege);

  /// Die Einträge für Auswahllisten: nur aktive, in Katalogreihenfolge.
  List<Sachgebiet> get auswahl => [
    for (final eintrag in eintraege)
      if (eintrag.aktiv) eintrag,
  ];

  @override
  List<Object?> get props => [eintraege];
}

class SachgebietKatalogFehler extends SachgebietKatalogStand {
  const SachgebietKatalogFehler();
}
