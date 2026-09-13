import 'package:automation_app/features/mandanten/domain/entities/akte.dart';
import 'package:equatable/equatable.dart';

/// Woher ein Ordner in der Auswahl „Akte zuordnen" kommt — und damit, an
/// welcher Stelle er steht. Die Reihenfolge der Werte **ist** die Reihenfolge
/// der Liste.
enum AktenAuswahlArt {
  /// Der Ordnername passt zum Namen des Mandanten (`nameVorschlagAusOrdner`).
  namensvorschlag,

  /// Weder zugeordnet noch vermerkt — der Zuordnungsstapel.
  offen,

  /// Als „ohne Mandantenbezug" vermerkt. Die Zuordnung nimmt den Vermerk
  /// zurück: Zuordnung sticht Vermerk.
  ohneMandantenbezug,

  /// Gehört schon einem anderen Mandanten — sichtbar, aber nicht wählbar.
  fremdZugeordnet,
}

/// Ein Ordner in der Auswahl „Akte zuordnen" (#132).
class AktenAuswahlEintrag extends Equatable {
  final Akte akte;
  final AktenAuswahlArt art;

  /// Ob der Ordner als „ohne Mandantenbezug" vermerkt ist. Eigenes Feld, weil
  /// ein vermerkter Ordner, der zum Namen passt, als
  /// [AktenAuswahlArt.namensvorschlag] vorn steht und den Vermerk trotzdem
  /// nennen soll.
  final bool vermerkt;

  const AktenAuswahlEintrag({
    required this.akte,
    required this.art,
    this.vermerkt = false,
  });

  /// Ein fremd zugeordneter Ordner ist gesperrt. Umhängen bräuchte den
  /// Besitzer, und den kennt die Übersicht nicht: sie lädt das Register
  /// seitenweise.
  bool get waehlbar => art != AktenAuswahlArt.fremdZugeordnet;

  @override
  List<Object?> get props => [akte, art, vermerkt];
}
