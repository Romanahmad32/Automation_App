import 'package:equatable/equatable.dart';

/// Ein Platzhalter einer Mail-Textvorlage, der nichts liefern wird — samt dem
/// Grund, im Klartext (§4.7, ergänzt am 02.09.2026).
///
/// Das Gegenstück zu `PlatzhalterBefund`, eine Stufe früher: Der Befund
/// entsteht am **gefüllten** Entwurf und weiß, welche Zeile entfällt; der
/// Mangel entsteht an der **Vorlage** und braucht dafür weder Vorgang noch
/// Mandant. Deshalb kann ihn der Editor zeigen, in dem beides fehlt.
class VorlagenMangel extends Equatable {
  /// Der Name, wie er in der Vorlage steht — ohne die geschweiften Klammern.
  final String platzhalter;

  /// Was auszusetzen ist, als Satz für den Anwalt.
  final String hinweis;

  const VorlagenMangel({required this.platzhalter, required this.hinweis});

  /// Der Platzhalter so, wie er in der Vorlage steht — mit Klammern.
  String get geschrieben => '{{$platzhalter}}';

  @override
  List<Object?> get props => [platzhalter, hinweis];
}
