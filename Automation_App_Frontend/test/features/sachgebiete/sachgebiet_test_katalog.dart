import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/sachgebiete/domain/repositories/sachgebiet_repository.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_cubit.dart';

/// Fester Sachgebietskatalog für Widget-Tests — die Seiten mit
/// `SachgebietKatalogBuilder` holen den `SachgebietCubit` über `getIt` und
/// brauchen deshalb eine Registrierung im Test-Setup.
class FesterSachgebietKatalog implements SachgebietRepository {
  final List<Sachgebiet> eintraege;

  FesterSachgebietKatalog([this.eintraege = beispielKatalog]);

  @override
  Future<List<Sachgebiet>> ladeSachgebiete() async => eintraege;

  /// Ein Ausschnitt des echten Katalogs (§7.1) — genug für Auswahl,
  /// Überschneidung und Vorbelegung.
  static const List<Sachgebiet> beispielKatalog = [
    Sachgebiet(
      id: 1,
      kuerzel: 'C03',
      name: 'Verkehrsrecht',
      rechtsgebietVorschlag: 'Verkehrsrecht',
      sortierung: 10,
      aktiv: true,
    ),
    Sachgebiet(
      id: 2,
      kuerzel: 'C03o',
      name: 'Ordnungswidrigkeitssache',
      rechtsgebietVorschlag: 'Ordnungswidrigkeitssache',
      sortierung: 20,
      aktiv: true,
    ),
    Sachgebiet(
      id: 3,
      kuerzel: 'C05',
      name: 'Strafrecht',
      rechtsgebietVorschlag: 'Strafrecht',
      sortierung: 30,
      aktiv: true,
    ),
  ];
}

/// In `setUp` aufrufen, bevor eine Seite mit Sachgebiets-Auswahl gepumpt wird;
/// `getIt.reset()` im `tearDown` räumt die Registrierung wieder ab.
void registriereSachgebietKatalog({SachgebietRepository? repository}) {
  getIt.registerLazySingleton<SachgebietCubit>(
    () => SachgebietCubit(repository ?? FesterSachgebietKatalog()),
  );
}
