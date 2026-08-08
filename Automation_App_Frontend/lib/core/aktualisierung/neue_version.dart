/// Eine veröffentlichte Version, die neuer ist als die laufende.
class NeueVersion {
  const NeueVersion({required this.nummer, required this.seite});

  /// Aufbereitet für die Anzeige: `1.1.0`, ohne führendes `v`.
  final String nummer;

  /// Die Release-Seite auf GitHub, von der heruntergeladen wird.
  final String seite;
}
