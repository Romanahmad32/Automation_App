import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:equatable/equatable.dart';

/// Wie fest der erkannte Bezug einer Mail zu einem Vorgang ist.
///
/// Die Unterscheidung ist keine Feinheit der Anzeige, sondern die Grenze
/// zwischen Behauptung und Vorschlag: [sicher] steht an einer Zeichenkette,
/// die die Kanzlei selbst vergeben hat und die in der Mail steht; [vermutet]
/// steht nur an einer Absenderadresse und wird dem Anwalt als Frage
/// vorgelegt, nie stillschweigend gesetzt.
enum BezugSicherheit { sicher, vermutet }

/// Der erkannte Bezug einer Posteingangsnachricht zu einem Vorgang.
///
/// Ein Wert, kein Vorgang: Der Erkenner ändert nichts, er schlägt vor. Ob und
/// wie der Bezug verwendet wird, entscheidet der Anwalt in der
/// Vorschlagskarte.
class Vorgangsbezug extends Equatable {
  const Vorgangsbezug({
    required this.vorgang,
    required this.sicherheit,
    required this.grund,
  });

  final Vorgang vorgang;
  final BezugSicherheit sicherheit;

  /// Ein Satzteil für die Vorschlagskarte, z. B. „Zeichen 144/26 C03 steht im
  /// Betreff" oder „Absender ist der Versicherer HUK-COBURG". Er steht neben
  /// dem Vorschlag, damit der Anwalt sieht, **woran** die App den Bezug
  /// festmacht, statt ihn glauben zu müssen.
  final String grund;

  @override
  List<Object?> get props => [vorgang.referenz, sicherheit, grund];
}
