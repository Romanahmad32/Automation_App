import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:equatable/equatable.dart';

/// Ein Wort in seinen Beugungsformen, mitten im Vorlagentext geschrieben:
/// `{{Mandant/Mandantin}}` (§4.7, ergänzt am 02.09.2026).
///
/// **Warum im Text und nicht in einer gepflegten Liste:** Die Wörter, die das
/// Deutsche hier beugt, sind viele und stehen jedes an seiner Stelle —
/// „unser**e** Mandant**in**", „als Geschädigt**e**", „sie". Eine Liste in den
/// Einstellungen hieße, jedes Wort erst anzumelden und seinen Namen zu
/// erinnern; hier stehen beide Fassungen dort, wo sie gelten, und sind beim
/// Schreiben der Vorlage zu sehen.
///
/// Zwei Formen genügen: Fehlt die dritte, rechnet [aus] sie aus — nie falsch
/// gebeugt, und wo das Deutsche eine kurze Schreibweise hat, in der kurzen
/// ([neutralAus]). Wer es anders will, schreibt die dritte Form dazu; sie
/// schlägt den Rückfall immer.
///
/// Der Schrägstrich ist als Kennzeichen sicher: `FeldDatenquelleErkennung`
/// wirft ihn beim Normalisieren weg, `{{Mandant/Mandantin}}` löste also auf
/// „mandantmandantin" auf und traf nie eine Datenquelle. Solche Vorlagen
/// verloren ihre Zeile stillschweigend — dieselbe Schreibweise, die jetzt
/// gemeint ist, war vorher ein unsichtbarer Fehler.
class Beugung extends Equatable {
  /// Form für einen männlichen Mandanten, z. B. „Mandant".
  final String maennlich;

  /// Form für eine weibliche Mandantin, z. B. „Mandantin".
  final String weiblich;

  /// Form ohne Geschlechtsbezug. Ohne dritte Form in der Vorlage rechnet
  /// [neutralAus] sie aus.
  final String neutral;

  /// Ob [neutral] in der Vorlage **steht** (dritte Form) oder ausgerechnet
  /// wurde. Nur für den Vorlageneditor: Er darf auf eine errechnete Form
  /// hinweisen, denn nur die kann der Anwalt noch verbessern.
  final bool neutralGeschrieben;

  const Beugung({
    required this.maennlich,
    required this.weiblich,
    required this.neutral,
    this.neutralGeschrieben = true,
  });

  /// Ob [inhalt] — der Text zwischen den Klammern — als Beugung gemeint ist.
  ///
  /// Bewusst nur am Schrägstrich und nicht daran, ob die Formen taugen: Ein
  /// Platzhalter mit Schrägstrich **ist** eine Beugung, auch eine misslungene.
  /// Sonst fiele `{{Mandant/}}` auf die Namenserkennung zurück und bekäme dort
  /// die Auskunft „kein Feld dieses Namens", die am Fehler vorbeigeht.
  static bool istGemeint(String inhalt) => inhalt.contains(_trenner);

  /// Die Formen aus [inhalt], oder null, wenn daraus keine Beugung wird: kein
  /// Schrägstrich, mehr als drei Formen oder eine davon leer.
  ///
  /// Null heißt nicht „stillschweigend nichts": Der Versanddialog erklärt die
  /// Fehlstelle (`PlatzhalterFehlstelle`), und weil [istGemeint] die Absicht
  /// unabhängig von ihrem Gelingen erkennt, sagt er auch, was gemeint war.
  static Beugung? aus(String inhalt) {
    if (!istGemeint(inhalt)) return null;

    final formen = inhalt.split(_trenner).map((form) => form.trim()).toList();
    if (formen.length > 3) return null;
    if (formen.any((form) => form.isEmpty)) return null;

    return Beugung(
      maennlich: formen[0],
      weiblich: formen[1],
      neutral: formen.length == 3
          ? formen[2]
          : neutralAus(formen[0], formen[1]),
      neutralGeschrieben: formen.length == 3,
    );
  }

  /// Die neutrale Form aus zwei gegebenen — die Regel, die greift, wenn keine
  /// dritte in der Vorlage steht.
  ///
  /// **Ist die eine Form der Anfang der anderen, kommt der Unterschied in
  /// Klammern:** „Mandant"/„Mandantin" wird zu „Mandant(in)",
  /// „Geschädigter"/„Geschädigte" zu „Geschädigte(r)". Das ist die
  /// Schreibweise, die das Rechtsdeutsch dafür hat — den gemeinsamen
  /// Wortstamm wiederholt man nicht, und „Geschädigter/Geschädigte" daneben
  /// liest sich hölzern.
  ///
  /// Sonst bleiben es beide mit Schrägstrich: „der/die", „er/sie",
  /// „sein/ihr". Genau dort wäre eine Klammer falsch — die Formen teilen
  /// keinen Stamm, und „d(er/ie)" wäre Unsinn. Die Regel greift also nur, wo
  /// sie nachweislich hinkommt; sonst gilt der Rückfall, der immer geht.
  ///
  /// Lauten beide gleich, steht die Form **einmal** da: Bei
  /// `{{Rechtsanwalt/Rechtsanwalt}}` wäre alles andere eine Verdopplung.
  static String neutralAus(String maennlich, String weiblich) {
    if (maennlich == weiblich) return maennlich;
    if (weiblich.startsWith(maennlich)) {
      return '$maennlich(${weiblich.substring(maennlich.length)})';
    }
    if (maennlich.startsWith(weiblich)) {
      return '$weiblich(${maennlich.substring(weiblich.length)})';
    }
    return '$maennlich$_trenner$weiblich';
  }

  /// Die Form, die zur Anredeart dieser Mail passt (§5.1). Bei
  /// [Anrede.keine] die neutrale — geraten wird nicht.
  String formFuer(Anrede anrede) => switch (anrede) {
    Anrede.herr => maennlich,
    Anrede.frau => weiblich,
    Anrede.keine => neutral,
  };

  /// Wie die Beugung in der Vorlage steht — für die Auswahl im Vorlageneditor
  /// und die Übersicht im Versanddialog.
  ///
  /// **Mit dritter Form, wenn sie dort steht** (behoben am 02.09.2026): Vorher
  /// wurde immer die zweiformige Schreibweise gebaut, und die Vorschau nannte
  /// bei `{{Mandant/Mandantin/Mandantschaft}}` einen Platzhalter, der so nicht
  /// im Text vorkam — wer danach suchte, fand nichts, und es sah aus, als sei
  /// die dritte Form übergangen worden.
  String get geschrieben => neutralGeschrieben
      ? '{{$maennlich$_trenner$weiblich$_trenner$neutral}}'
      : '{{$maennlich$_trenner$weiblich}}';

  static const String _trenner = '/';

  @override
  List<Object?> get props => [maennlich, weiblich, neutral, neutralGeschrieben];
}
