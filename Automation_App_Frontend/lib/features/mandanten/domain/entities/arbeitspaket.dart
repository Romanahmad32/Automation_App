import 'package:automation_app/features/mandanten/domain/entities/aktentyp.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:equatable/equatable.dart';

/// Ein Arbeitspaket für den KI-Agenten, der die Importdatei erzeugt (§5.1,
/// §6.1): ein Ausschnitt der noch offenen Akten-Ordner, angereichert um alles,
/// was der Agent zum Zuordnen braucht.
///
/// Der Anlass ist die Größenordnung: rund 4000 Ordner liegen unter dem
/// Stammordner, und ein Agent, dem man sie auf einmal vorlegt, arbeitet
/// entweder halb oder gar nicht. Das Paket schneidet daraus eine Portion, die
/// er in einem Zug schafft — der Fortschritt entsteht dadurch in Schritten,
/// die abgeschlossen werden können.
///
/// **Eigenes Format, eigene Fassung.** Dies ist die *Eingabe* für den Agenten,
/// nicht die Importdatei, die er zurückliefert (`MandantenImportDatei`,
/// `docs/MANDANTEN_IMPORT.md`). Beide zählen ihre Fassung getrennt: an dieser
/// Seite darf sich etwas ändern, ohne dass die Importdatei nachzieht.
///
/// Die Paketnummer reist bewusst **nicht** in die Importdatei zurück. Welche
/// Datei zu welchem Paket gehört, rechnet das Backend aus den Ordnernamen aus
/// — eine Frage weniger an den Anwalt.
class Arbeitspaket extends Equatable {
  /// Die einzige Fassung, die der Agent zu lesen bekommt.
  static const int aktuelleVersion = 1;

  final int version;

  /// Fortlaufende Nummer des Pakets, vom Backend vergeben.
  final int paket;

  final DateTime erstelltAm;

  /// Der Akten-Stammordner, unter dem die Ordner aus [ordner] liegen — damit
  /// der Agent die Akten wirklich öffnen kann und nicht nur Namen sieht.
  final String stammordner;

  /// Der Auftragstext für den Agenten (`ImportAnleitung.paketText`). Er reist
  /// in der Datei mit, damit das Paket auch dann noch verständlich ist, wenn
  /// es Tage später bearbeitet wird — und damit der Auftrag nicht allein an
  /// der Zwischenablage hängt, die ein einziges Kopieren unterwegs leert.
  ///
  /// **Das Feld heißt weiter `anleitung`**, obwohl die Oberfläche überall
  /// „Auftrag" sagt: Der Name steht im Format der Fassung 1, und ihn
  /// umzubenennen wäre ein Formatwechsel für einen Wortlaut.
  final String anleitung;

  /// Der bereits erfasste Mandantenbestand — der Agent soll vorhandene
  /// Mandanten wiedererkennen und keine Dubletten anlegen.
  final List<BekannterMandant> bekannteMandanten;

  /// Die Ordner dieses Pakets, **nach Mandanten gebündelt**: die Ordner einer
  /// Person stehen zusammenhängend hintereinander, die Gruppen selbst
  /// alphabetisch (Verkehrsunfall-Kandidaten zuerst) — siehe
  /// `ArbeitspaketBauen`.
  ///
  /// Die Bündelung ist allein Reihenfolge und bekommt **kein** eigenes Feld:
  /// der Agent liest die Liste ohnehin von oben nach unten, und ein Feld
  /// „Gruppe" wäre eine Behauptung über die Identität einer Person, die aus
  /// einem Ordnernamen geraten ist.
  final List<ArbeitspaketOrdner> ordner;

  const Arbeitspaket({
    this.version = aktuelleVersion,
    required this.paket,
    required this.erstelltAm,
    this.stammordner = '',
    this.anleitung = '',
    this.bekannteMandanten = const [],
    this.ordner = const [],
  });

  /// Die Ordnernamen des Pakets — das, was beim Verbuchen
  /// (`POST /api/ImportPakete`) über die Leitung geht.
  List<String> get ordnernamen => [for (final o in ordner) o.ordnername];

  /// Vorgeschlagener Dateiname für den Speichern-Dialog.
  String get dateiname => 'arbeitspaket-$paket.json';

  /// Zeitangaben in UTC, wie überall auf der Leitung: der Agent läuft nicht
  /// zwingend in derselben Zeitzone wie die Kanzlei.
  Map<String, dynamic> toJson() => {
    'version': version,
    'paket': paket,
    'erstelltAm': erstelltAm.toUtc().toIso8601String(),
    'stammordner': stammordner,
    'anleitung': anleitung,
    'bekannteMandanten': [for (final m in bekannteMandanten) m.toJson()],
    'ordner': [for (final o in ordner) o.toJson()],
  };

  @override
  List<Object?> get props => [
    version,
    paket,
    erstelltAm,
    stammordner,
    anleitung,
    bekannteMandanten,
    ordner,
  ];
}

/// Ein offener Akten-Ordner, wie ihn der Agent vorgelegt bekommt.
///
/// [nameVorschlagVorname] und [nameVorschlagNachname] kommen unverändert aus
/// `nameVorschlagAusOrdner` und werden **nicht** nachgebessert: Der Vorschlag
/// ist eine Heuristik über eine Präfixtabelle und löst nicht jeden
/// Ordnernamen auf. Was er nicht auflöst, entscheidet der Agent am rohen
/// [ordnername], der ihm daneben mitgegeben wird.
class ArbeitspaketOrdner extends Equatable {
  final String ordnername;

  /// Der aus dem Präfix erkannte Aktentyp (`AktentypErkennung`).
  final Aktentyp aktentyp;

  final String nameVorschlagVorname;
  final String nameVorschlagNachname;

  /// Anzeigename des Mandanten, den `MandantErkennung` für diesen Ordner
  /// vorschlägt — `null`, wenn nichts gefunden wurde. Dann fehlen beide Felder
  /// in der Datei, statt leer dazustehen: ein leeres Feld läse sich wie eine
  /// Aussage („kein Mandant"), und das wäre eine, die niemand geprüft hat.
  final String? bekannterMandant;

  /// Warum [bekannterMandant] vorgeschlagen wird (Begründung aus
  /// `MandantVorschlag`).
  final String? begruendung;

  const ArbeitspaketOrdner({
    required this.ordnername,
    this.aktentyp = Aktentyp.ohnePraefix,
    this.nameVorschlagVorname = '',
    this.nameVorschlagNachname = '',
    this.bekannterMandant,
    this.begruendung,
  });

  Map<String, dynamic> toJson() => {
    'ordnername': ordnername,
    'aktentyp': aktentyp.name,
    'nameVorschlagVorname': nameVorschlagVorname,
    'nameVorschlagNachname': nameVorschlagNachname,
    if (bekannterMandant != null) 'bekannterMandant': bekannterMandant,
    if (bekannterMandant != null) 'begruendung': begruendung ?? '',
  };

  @override
  List<Object?> get props => [
    ordnername,
    aktentyp,
    nameVorschlagVorname,
    nameVorschlagNachname,
    bekannterMandant,
    begruendung,
  ];
}

/// Ein bereits erfasster Mandant, so knapp wie der Agent ihn braucht: woran er
/// ihn wiedererkennt (Name, seine Ordner, seine Kennzeichen) — und sonst
/// nichts. Anschrift, Telefonnummer und Notiz gehören dem Register und haben
/// in einer Datei, die das Haus verlässt, nichts zu suchen.
class BekannterMandant extends Equatable {
  final String anzeigename;
  final List<String> aktenOrdnernamen;
  final List<String> kennzeichen;

  const BekannterMandant({
    required this.anzeigename,
    this.aktenOrdnernamen = const [],
    this.kennzeichen = const [],
  });

  factory BekannterMandant.aus(Mandant mandant) => BekannterMandant(
    anzeigename: mandant.anzeigename,
    aktenOrdnernamen: mandant.aktenOrdnernamen,
    kennzeichen: mandant.kennzeichen,
  );

  Map<String, dynamic> toJson() => {
    'anzeigename': anzeigename,
    'aktenOrdnernamen': aktenOrdnernamen,
    'kennzeichen': kennzeichen,
  };

  @override
  List<Object?> get props => [anzeigename, aktenOrdnernamen, kennzeichen];
}
