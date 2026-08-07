import 'package:equatable/equatable.dart';

/// Eine Word-Vorlage aus dem Vorlagenordner des Anwenders.
class Vorlage extends Equatable {
  const Vorlage({
    required this.name,
    required this.pfad,
    required this.geaendertAm,
  });

  final String name;
  final String pfad;
  final DateTime geaendertAm;

  @override
  List<Object?> get props => [name, pfad, geaendertAm];
}

/// Der Vorlagenordner samt Inhalt.
///
/// Der Ordner liegt in `%APPDATA%\AutomationService\Vorlagen` und damit
/// außerhalb des Installationsverzeichnisses — ein Update fasst ihn nicht an.
/// Genau deshalb kennt ihn das Frontend nicht selbst, sondern erfragt ihn beim
/// Dienst: der Pfad wird an genau einer Stelle bestimmt.
class VorlagenUebersicht extends Equatable {
  const VorlagenUebersicht({required this.verzeichnis, required this.vorlagen});

  final String verzeichnis;
  final List<Vorlage> vorlagen;

  @override
  List<Object?> get props => [verzeichnis, vorlagen];
}
