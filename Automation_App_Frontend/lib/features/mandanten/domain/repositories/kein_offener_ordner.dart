import 'package:automation_app/core/general_classes/failures/failure.dart';

/// Es ist kein Ordner mehr offen: Der Dienst antwortet auf
/// `POST api/Arbeitspakete` mit 409 und bucht **kein** leeres Paket.
///
/// Das ist der Endzustand des Vorgangs und kein Fehler — der Zuordnungsstapel
/// ist abgearbeitet. Ein leeres Paket in der Historie stünde dagegen für immer
/// als „nie eingelesen" darin und täuschte eine Lücke vor, die es nie gab.
class KeinOffenerOrdnerException implements Exception {
  final String message;

  const KeinOffenerOrdnerException(this.message);

  @override
  String toString() => 'KeinOffenerOrdnerException: $message';
}

/// Derselbe Fall, wie er aus dem Repository herauskommt.
///
/// Ein eigener Typ und nicht nur ein Text: Der Cubit muss „alles erledigt" von
/// „der Dienst antwortet nicht" unterscheiden können, und ein Vergleich auf
/// Meldungstexte wäre beim nächsten Umformulieren still falsch. Was daraus auf
/// dem Bildschirm wird, entscheidet die Oberfläche — rot wäre es jedenfalls
/// nicht.
class KeinOffenerOrdnerFailure extends Failure {
  KeinOffenerOrdnerFailure({required super.message});
}
