import 'package:equatable/equatable.dart';

/// Auf welchem Weg die Nachricht das Haus verließ (§4.7).
enum VersandWeg {
  /// Die App hat über das Postfach der Kanzlei gesendet.
  direktversand('Direktversand'),

  /// An Outlook übergeben — **nicht** gesendet. Ob dort abgeschickt wurde,
  /// weiß die App nicht (§4.8).
  outlookEntwurf('OutlookEntwurf'),

  /// Als Entwurfsdatei abgelegt, weil Outlook nicht erreichbar war.
  entwurfsdatei('Entwurfsdatei');

  final String kennung;

  const VersandWeg(this.kennung);

  static VersandWeg aus(String? kennung) => VersandWeg.values.firstWhere(
    (weg) => weg.kennung == kennung,
    orElse: () => VersandWeg.direktversand,
  );

  /// True nur beim Direktversand: Nur dort weiß die App, dass die Mail
  /// eingeliefert wurde. Der Unterschied gehört auf den Schirm — ein
  /// Protokoll, das eine Übergabe als Versand ausgibt, wäre als Nachweis
  /// schlechter als keines.
  bool get istNachweis => this == VersandWeg.direktversand;
}

/// Ein Versand zu einem Vorgang (§4.7): wann, an wen, mit welchen Anhängen.
///
/// Für eine Kanzlei ist das der Nachweis, dass das Anspruchsschreiben hinaus
/// ist. Die Mail selbst liegt im Ordner „Gesendet" des Postfachs — und damit
/// in Outlook am selben Konto; dieser Eintrag ist der Index darüber, nicht
/// sein Ersatz.
///
/// Das Backend liefert daneben eine `messageId`. Sie steht hier nicht: Sie
/// wäre für den Anwalt keine Auskunft, und ein Feld, das niemand liest, sieht
/// beim nächsten Blick aus wie eines, das jemand zu lesen vergessen hat.
class VersandEintrag extends Equatable {
  final String vorgangReferenz;
  final DateTime gesendetAm;
  final VersandWeg weg;
  final String absender;
  final List<String> empfaenger;
  final List<String> kopie;
  final String betreff;

  /// Die Namen, unter denen die Anhänge hinausgingen — nicht die auf Platte.
  final List<String> anhaenge;

  /// Ob die Kopie im Ordner „Gesendet" landete.
  final bool imGesendetOrdner;

  const VersandEintrag({
    required this.vorgangReferenz,
    required this.gesendetAm,
    required this.weg,
    this.absender = '',
    this.empfaenger = const [],
    this.kopie = const [],
    this.betreff = '',
    this.anhaenge = const [],
    this.imGesendetOrdner = false,
  });

  factory VersandEintrag.fromJson(Map<String, dynamic> json) => VersandEintrag(
    vorgangReferenz: json['vorgangReferenz'] as String? ?? '',
    gesendetAm:
        DateTime.tryParse(json['gesendetAm'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    weg: VersandWeg.aus(json['weg'] as String?),
    absender: json['absender'] as String? ?? '',
    empfaenger: _texte(json['empfaenger']),
    kopie: _texte(json['kopie']),
    betreff: json['betreff'] as String? ?? '',
    anhaenge: _texte(json['anhaenge']),
    imGesendetOrdner: json['imGesendetOrdner'] as bool? ?? false,
  );

  static List<String> _texte(Object? wert) => [
    for (final eintrag in (wert as List?) ?? const []) eintrag as String,
  ];

  /// Alle Angeschriebenen, „An" und „Kopie" zusammen.
  List<String> get alleEmpfaenger => [...empfaenger, ...kopie];

  @override
  List<Object?> get props => [
    vorgangReferenz,
    gesendetAm,
    weg,
    absender,
    empfaenger,
    kopie,
    betreff,
    anhaenge,
    imGesendetOrdner,
  ];
}
