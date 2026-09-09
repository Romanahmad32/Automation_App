/// Fachlicher Fehlertext ohne technische HTTP-Details.
class SynchronisationsFehler implements Exception {
  final String meldung;
  const SynchronisationsFehler(this.meldung);

  @override
  String toString() => meldung;
}
