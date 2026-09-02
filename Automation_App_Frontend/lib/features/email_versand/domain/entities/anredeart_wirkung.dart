import 'package:equatable/equatable.dart';

/// Worauf die gewählte **Anredeart** in dieser Mail gerade wirkt (§4.7,
/// ergänzt am 02.09.2026) — die Anredezeile, gebeugte Wörter im Text, beides
/// oder nichts.
///
/// **Der Mangel, der diese Datei trägt:** Über der Chipreihe stand der feste
/// Satz „Beugt die Anrede und die Wortformen im Text". Das ist ein
/// Versprechen, das in der häufigsten Mail dieser Kanzlei niemand einlöst: Geht
/// sie an die Versicherung, ist die Anrede neutral, und die mitgelieferte
/// Vorlage enthält kein gebeugtes Wort. Der Klick auf „Frau" tat dann sichtbar
/// nichts — und die Reihe behauptete weiter, er täte zweierlei. Ein fester
/// Satz kann nicht sagen, was gerade gilt; dieser rechnet es aus.
///
/// **Nicht raten, sondern zählen.** Die Wörter kommen aus derselben Prüfung,
/// die der Vorlageneditor benutzt (`VorlagenPruefung.beugungen`) — und die
/// zählt jede Beugung **einmal**, auch wenn sie mehrfach im Text steht: Die
/// Zahl beantwortet „wie viele Angaben beugen sich", nicht „wie oft".
class AnredeartWirkung extends Equatable {
  /// Ob die Anredezeile mitgeht: Sie muss namentlich sein **und** die Vorlage
  /// muss eine Stelle für sie haben. Eine neutrale Zeile hat kein Geschlecht,
  /// und eine Vorlage ohne `{{Anrede}}` hat gar keine Zeile.
  final bool anredezeile;

  /// Wie viele gebeugte Angaben im Text stehen (`{{Mandant/Mandantin}}`).
  final int woerter;

  /// Ob die Vorlage **gar keine** Anredezeile hat (kein `{{Anrede}}`).
  ///
  /// Eigenes Feld und nicht mit [anredezeile] verrechnet, weil daran ein
  /// **anderer Satz** hängt: „die Anrede ist neutral" wäre hier falsch — es
  /// gibt keine. Beide zugleich wahr geht nicht; wo keine Zeile ist, wirkt
  /// auch keine.
  final bool ohneAnredezeile;

  const AnredeartWirkung({
    this.anredezeile = false,
    this.woerter = 0,
    this.ohneAnredezeile = false,
  });

  /// Ob die Anredeart überhaupt etwas bewegt. False heisst nicht „falsch
  /// eingestellt", sondern „hier gerade ohne Aufgabe" — und genau das darf der
  /// Anwalt lesen, statt es an einem Klick ohne Wirkung zu merken.
  bool get wirkt => anredezeile || woerter > 0;

  /// Der Satz unter der Chipreihe.
  String get hinweis {
    if (anredezeile && woerter > 0) {
      return 'Wirkt auf die Anrede und auf $_woerter in der Vorlage.';
    }
    // Dass im Text keine gebeugte Form steht, fehlt hier niemandem: Die
    // Anredeart tut ihre Arbeit. Es zu melden wäre ein Mangel, der keiner ist.
    if (anredezeile) return 'Wirkt auf die Anrede.';
    if (woerter > 0) {
      return ohneAnredezeile
          ? 'Wirkt auf $_woerter in der Vorlage — eine Anredezeile hat sie '
                'nicht.'
          : 'Wirkt auf $_woerter in der Vorlage — die Anrede ist neutral.';
    }
    if (ohneAnredezeile) {
      return 'Wirkt gerade nirgends: Die Vorlage hat keine Anredezeile und '
          'keine gebeugte Form.';
    }
    // Nur hier steht das Muster dazu: Wer eine Wirkung sucht und keine
    // bekommt, soll erfahren, wie man eine herstellt. In den Fällen darüber
    // wäre es Zierde — dort wirkt sie, oder es fehlt die Zeile, und das ist
    // eine andere Aufgabe.
    return 'Wirkt gerade nirgends: Die Anrede ist neutral, und im Text steht '
        'keine gebeugte Form („{{Mandant/Mandantin}}").';
  }

  String get _woerter =>
      woerter == 1 ? 'ein gebeugtes Wort' : '$woerter gebeugte Wörter';

  @override
  List<Object?> get props => [anredezeile, woerter, ohneAnredezeile];
}
