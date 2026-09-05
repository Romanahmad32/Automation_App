import 'package:equatable/equatable.dart';

/// Die Zustände, die `GET /api/Settings/ordner` je Ordnerfeld melden kann.
///
/// Zeichenketten und kein Dart-`enum`: Es sind die Werte des Dienstes, und ein
/// unbekannter Wert soll die Anzeige nicht sprengen, sondern schlicht keinen
/// Satz ergeben. Ein `enum` müsste dafür trotzdem einen Auffangwert tragen.
class OrdnerZustandArten {
  const OrdnerZustandArten._();

  /// Feld leer, und es gibt auch keinen abgeleiteten Ordner — hier legt die
  /// App nichts ab.
  static const String nichtGesetzt = 'nichtGesetzt';

  /// Feld leer, der wirksame Ordner entsteht unter dem Ordner für App-Daten.
  static const String abgeleitet = 'abgeleitet';

  /// Nur die Vorlagen: Feld leer, es gilt der App-Ordner unter %APPDATA% —
  /// der Stand vor dieser Einstellung.
  static const String standard = 'standard';

  /// Gesetzt, aufgelöst, und der Ordner liegt da.
  static const String bereit = 'bereit';

  /// Gesetzt und aufgelöst, aber der Ordner liegt (noch) nicht da. Kein
  /// Fehler: Angelegt wird beim ersten Schreiben, nicht beim Speichern.
  static const String ordnerFehlt = 'ordnerFehlt';

  /// Relativ abgelegt, aber die OneDrive-Variable, gegen die gerechnet wurde,
  /// ist auf diesem Rechner nicht gesetzt. Das ist der einzige Zustand, der
  /// wirklich stört — und der einzige, den absichtlich niemand still
  /// „repariert", indem er auf eine andere Wurzel ausweicht (#103).
  static const String ankerFehlt = 'ankerFehlt';
}

/// Wie es um **einen** der fünf Ordner steht: was gespeichert ist, was
/// tatsächlich gilt und warum.
///
/// Der Dienst beantwortet das, weil nur er es beantworten kann: Er löst die
/// relative Speicherform gegen die Umgebung auf, kennt die Ableitungen
/// (Vorlagen/Register/Sicherungen unter dem Ordner für App-Daten) und sieht
/// auf der Platte nach. Das Frontend rechnet nichts davon nach — es zeigt an,
/// was hier steht.
class OrdnerZustand extends Equatable {
  /// camelCase-Name des Feldes in `KanzleiSettings`: `appDatenOrdner`,
  /// `aktenStammordner`, `vorlagenOrdner`, `registerAblageOrdner` oder
  /// `sicherungsAblageOrdner`.
  final String feld;

  /// Die Speicherform — absolut oder mit Anker in Prozentzeichen. Leer heißt:
  /// nicht gesetzt.
  final String gespeichert;

  /// Der Ordner, den der Dienst tatsächlich nutzt. Leer heißt: keiner.
  final String wirksam;

  /// Einer der Werte aus [OrdnerZustandArten].
  final String zustand;

  /// Name der OneDrive-Umgebungsvariablen bei relativer Speicherung, sonst
  /// leer.
  final String anker;

  const OrdnerZustand({
    required this.feld,
    required this.zustand,
    this.gespeichert = '',
    this.wirksam = '',
    this.anker = '',
  });

  factory OrdnerZustand.fromJson(Map<String, dynamic> json) => OrdnerZustand(
    feld: json['feld'] as String? ?? '',
    zustand: json['zustand'] as String? ?? OrdnerZustandArten.nichtGesetzt,
    gespeichert: json['gespeichert'] as String? ?? '',
    wirksam: json['wirksam'] as String? ?? '',
    anker: json['anker'] as String? ?? '',
  );

  /// Ob dieser Ordner auf diesem Rechner nicht aufzulösen ist — der eine
  /// Zustand, der als Fehler gezeigt gehört und nicht als stiller Hinweis.
  bool get stoert => zustand == OrdnerZustandArten.ankerFehlt;

  @override
  List<Object?> get props => [feld, zustand, gespeichert, wirksam, anker];
}
