import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/domain/entities/ordnernamen_menge.dart';
import 'package:equatable/equatable.dart';

/// Woran eine Importdatei gemessen wird: die Ordner, die es unter dem
/// Stammordner wirklich gibt, und das Mandantenregister.
///
/// Beides kommt **einmal** in die Importseite und bleibt dort, solange sie
/// offen ist — auch über „Andere Datei" hinweg. Der Akten-Scan liest rund
/// viertausend Ordner der ersten Ebene; ihn nach jeder berichtigten Zeile
/// erneut anzustoßen wäre die Seite, die nach jedem Klick stehenbleibt.
///
/// Fehlt eines von beidem, ist das kein Fehler, sondern ein leeres Feld: ohne
/// Scan wird keine Ordnerangabe beanstandet (siehe `OrdnerPruefung`), ohne
/// Register gibt es keine Ähnlichkeitshinweise. Der Import selbst läuft in
/// beiden Fällen weiter — er ist die Hauptsache, diese Auskunft die Zugabe.
class ImportUmfeld extends Equatable {
  /// Die Ordnernamen der ersten Ebene unter dem Stammordner, in der
  /// Schreibweise der Platte. Genau diese Schreibweise gehört in die Datei,
  /// deshalb wird sie hier unverändert mitgeführt und nicht kleingeschrieben.
  final List<String> ordnernamen;

  /// Das Register, gegen das der Ähnlichkeitshinweis rechnet. Bewusst der
  /// ganze Bestand und nicht die geladene Seite der Übersicht: ein Vorschlag,
  /// der vom Scrollstand einer anderen Seite abhinge, wäre keiner.
  final List<Mandant> mandanten;

  const ImportUmfeld({this.ordnernamen = const [], this.mandanten = const []});

  /// Dieselben Ordnernamen, ohne Rücksicht auf Groß- und Kleinschreibung —
  /// Windows kennt „VUnfallursache Mark" und „Vunfallursache Mark" als einen
  /// Ordner.
  OrdnernamenMenge get menge => OrdnernamenMenge(ordnernamen);

  @override
  List<Object?> get props => [ordnernamen, mandanten];
}
