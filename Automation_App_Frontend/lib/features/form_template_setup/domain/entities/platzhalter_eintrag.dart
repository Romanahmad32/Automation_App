import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_gruppe.dart';
import 'package:equatable/equatable.dart';

/// Ein Platzhalter, wie er zur **Auswahl** angeboten wird (§4.7, §5.3): der
/// Name, der in die Vorlage geschrieben wird, und was er im Klartext liefert.
///
/// Eigener Typ, weil zwei Herkünfte in derselben Liste stehen müssen: die
/// Vorgangsfelder aus `FeldDatenquelle` und die zwei Angaben, die beim
/// Verfassen einer Mail entstehen (Anrede, Zusatzgruß) und an keinem Vorgang
/// stehen. Ohne gemeinsame Form müsste die Oberfläche zwei Listen mischen und
/// dabei entscheiden, was wohin gehört — eine Entscheidung, die in den Katalog
/// gehört und nicht in ein Widget.
class PlatzhalterEintrag extends Equatable {
  /// Der Name ohne Klammern, z. B. `MandantName`.
  final String platzhalter;

  /// Was er liefert, im Klartext — die Zeile, die der Anwalt liest.
  final String bezeichnung;

  final PlatzhalterGruppe gruppe;

  const PlatzhalterEintrag({
    required this.platzhalter,
    required this.bezeichnung,
    required this.gruppe,
  });

  /// Der Platzhalter so, wie er in die Vorlage geschrieben wird.
  String get geschrieben => '{{$platzhalter}}';

  @override
  List<Object?> get props => [platzhalter, bezeichnung, gruppe];
}
