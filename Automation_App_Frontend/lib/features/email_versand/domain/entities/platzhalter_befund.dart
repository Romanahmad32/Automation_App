import 'package:equatable/equatable.dart';

/// Was ein `{{Platzhalter}}` einer Mail-Textvorlage ergeben hat (§4.7) — für
/// die Übersicht im Versanddialog.
///
/// Sie beantwortet die Frage, die ein fertig gefüllter Text nicht mehr
/// beantwortet: **Woher kommt das, und was ist leer geblieben?** Ohne sie
/// sieht ein falsch belegter Platzhalter aus wie ein Tippfehler im Text.
///
/// Ein leerer Befund trägt deshalb auch seine **Stelle** in der Vorlage
/// ([zeile]) und die Folge ([zeileEntfaellt]) bei sich: Der übersprungene
/// Platzhalter ist im gefüllten Text nicht mehr zu sehen — er hat seine Zeile
/// mitgenommen —, und ohne den Hinweis, *wo* sie stand, bleibt nur die Suche
/// im Vorlagentext.
class PlatzhalterBefund extends Equatable {
  /// Der Name, wie er in der Vorlage steht — ohne die geschweiften Klammern.
  final String name;

  /// Was eingesetzt wurde; leer heißt: nichts, und die Zeile entfällt —
  /// es sei denn, ein anderer Platzhalter derselben Zeile trug etwas bei.
  final String wert;

  /// Woher der Wert stammt, im Klartext („aus dem Mandanten"). Leer, wenn es
  /// nichts einzusetzen gab.
  final String herkunft;

  /// Wo der Platzhalter in der Vorlage steht: die Zeile des Nachrichtentexts,
  /// von 1 an gezählt. **0 heißt Betreffzeile** — die hat keine Zeilennummer,
  /// und ein eigenes Feld dafür wäre ein zweiter Weg, dasselbe zu sagen.
  final int zeile;

  /// Ob diese Zeile im gefüllten Text ganz entfällt: Sie trug Platzhalter, und
  /// **keiner** davon hatte einen Wert (§4.7). Blieb ein anderer Platzhalter
  /// derselben Zeile gefüllt, bleibt die Zeile stehen und verliert nur diesen
  /// einen Wert — ein Unterschied, den der Anwalt sehen muss: einmal fehlt ein
  /// ganzer Satz, einmal nur ein Wort darin.
  final bool zeileEntfaellt;

  /// Was die Quelle im Klartext liefert („Mandant · Telefon"). Leer für die
  /// Platzhalter, die beim Verfassen entstehen — ihre Namen sagen es selbst.
  final String bezeichnung;

  /// **Warum** leer geblieben ist, und wo die Angabe gepflegt wird („im
  /// Mandantenregister nicht erfasst"). Die Auskunft, die vorher fehlte: Dass
  /// eine Zeile entfällt, sah der Anwalt; woran es lag, nicht.
  final String fehlstelle;

  /// Die **weiteren** Zeilen, die derselbe Name mitnimmt (ergänzt am
  /// 03.09.2026) — aufsteigend, ohne [zeile].
  ///
  /// Ein Name kommt in der Übersicht nur einmal vor, sonst stünde
  /// `{{MandantName}}` fünfmal untereinander. Bis dahin verschwieg diese
  /// Zusammenfassung aber die übrigen Stellen: `{{Referenz}}` im Betreff
  /// **und** in „Unser Zeichen: {{Referenz}}" meldete nur „fällt aus dem
  /// Betreff", und dass Zeile 7 dazu ersatzlos weg war, stand nirgends. Genau
  /// das soll diese Klasse auffindbar machen.
  final List<int> weitereEntfallene;

  const PlatzhalterBefund({
    required this.name,
    this.wert = '',
    this.herkunft = '',
    this.zeile = 0,
    this.zeileEntfaellt = false,
    this.bezeichnung = '',
    this.fehlstelle = '',
    this.weitereEntfallene = const [],
  });

  bool get istLeer => wert.trim().isEmpty;

  bool get imBetreff => zeile == 0;

  /// Der Platzhalter so, wie er in der Vorlage steht — mit Klammern.
  String get geschrieben => '{{$name}}';

  /// Die Stelle im Klartext, wie sie in der Übersicht steht.
  String get stelle => imBetreff ? 'im Betreff' : 'in Zeile $zeile';

  /// Was das Leerbleiben für den Text bedeutet — der Satz, der in der
  /// Übersicht anstelle des Werts steht.
  String get folge {
    if (!istLeer) return '';
    final erste = imBetreff
        ? 'fällt aus dem Betreff'
        : zeileEntfaellt
        ? 'Zeile $zeile entfällt'
        : 'Zeile $zeile bleibt, ohne diesen Wert';
    if (weitereEntfallene.isEmpty) return 'bleibt leer — $erste';
    return 'bleibt leer — $erste, $_weitere';
  }

  /// Die übrigen entfallenen Zeilen im Klartext.
  String get _weitere => weitereEntfallene.length == 1
      ? 'Zeile ${weitereEntfallene.single} entfällt'
      : 'die Zeilen ${weitereEntfallene.join(', ')} entfallen';

  @override
  List<Object?> get props => [
    name,
    wert,
    herkunft,
    zeile,
    zeileEntfaellt,
    bezeichnung,
    fehlstelle,
    weitereEntfallene,
  ];
}
