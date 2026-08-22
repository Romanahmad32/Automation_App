import 'package:automation_app/features/mandanten/domain/entities/akte.dart';

/// Die Namen der vorhandenen Fälle (Unterordner) im Akten-Ordner [ordnername].
/// Leer, wenn kein Ordner gewählt ist oder es ihn im Dateisystem noch nicht
/// gibt — dann bleibt nur „neu anlegen".
List<String> faelleZuOrdner(List<Akte> akten, String ordnername) {
  if (ordnername.isEmpty) return const [];
  for (final akte in akten) {
    if (akte.ordnername == ordnername) {
      return [for (final fall in akte.faelle) fall.name];
    }
  }
  return const [];
}
