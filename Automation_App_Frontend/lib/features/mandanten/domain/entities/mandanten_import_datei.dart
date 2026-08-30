import 'package:equatable/equatable.dart';

/// Eine Importdatei mit dem, was außerhalb der App über den Aktenbestand
/// zusammengetragen wurde (§5.1/§6.1). Beschrieben ist das Format in
/// `docs/MANDANTEN_IMPORT.md`; diese Klasse ist dessen Dart-Seite.
///
/// Der Anlass ist die Größenordnung: rund 4000 Ordner einzeln von Hand einem
/// Mandanten zuzuordnen ist nicht leistbar. Die Zuordnung entsteht deshalb
/// maschinell aus den Ordnernamen und Aktentexten und kommt als Datei herein —
/// die App prüft sie, zeigt sie und schreibt erst nach Freigabe.
///
/// Gelesen wird bewusst nachsichtig: fehlende Felder sind leer, unbekannte
/// werden übergangen. Der Erzeuger ist ein Programm, kein Formular, und eine
/// Datei mit 4000 brauchbaren und einer krummen Zeile darf nicht als Ganzes
/// scheitern.
class MandantenImportDatei extends Equatable {
  /// Die einzige Fassung, die Frontend und Dienst lesen.
  static const aktuelleVersion = 1;

  final int version;
  final List<ImportMandantEintrag> mandanten;

  /// Ordner, die der Erzeuger als „gehört keinem Mandanten" erkannt hat
  /// (Buchhaltung, Vorlagen, Ablagen). Sie werden als Vermerk gesetzt und
  /// verlassen damit den Zuordnungsstapel, ohne einzeln durchgesehen zu werden.
  final List<String> ohneMandantenbezug;

  const MandantenImportDatei({
    this.version = aktuelleVersion,
    this.mandanten = const [],
    this.ohneMandantenbezug = const [],
  });

  /// Was die Datei insgesamt an Ordnern anfasst — die Zahl, an der sich der
  /// Nutzen misst.
  int get ordnerGesamt =>
      mandanten.fold(0, (summe, e) => summe + e.aktenOrdnernamen.length) +
      ohneMandantenbezug.length;

  factory MandantenImportDatei.fromJson(Map<String, dynamic> json) {
    final eintraege = json['mandanten'];
    final ohne = json['ohneMandantenbezug'];
    return MandantenImportDatei(
      version: json['version'] as int? ?? aktuelleVersion,
      mandanten: eintraege is List
          ? [
              for (final eintrag in eintraege.whereType<Map<String, dynamic>>())
                ImportMandantEintrag.fromJson(eintrag),
            ]
          : const [],
      ohneMandantenbezug: ohne is List
          ? ohne.whereType<String>().toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'mandanten': [for (final eintrag in mandanten) eintrag.toJson()],
    'ohneMandantenbezug': ohneMandantenbezug,
  };

  @override
  List<Object?> get props => [version, mandanten, ohneMandantenbezug];
}

/// Ein Mandant in der Importdatei. Alles außer dem Namen ist freiwillig: was im
/// Aktenbestand nicht auffindbar war, bleibt leer, statt geraten zu werden.
class ImportMandantEintrag extends Equatable {
  final String anrede;
  final String vorname;
  final String nachname;
  final String strasseHausnummer;
  final String postleitzahl;
  final String ort;
  final String emailAdresse;
  final String telefonnummer;
  final String notiz;

  /// Die Akten-Ordner unter dem Stammordner, die zu diesem Mandanten gehören.
  final List<String> aktenOrdnernamen;
  final List<String> kennzeichen;

  /// Woher der Erzeuger die Angaben hat — frei, meist ein Datei- oder
  /// Ordnerpfad. Macht eine zweifelhafte Zeile nachprüfbar, statt sie nur
  /// bezweifelbar zu lassen.
  final String quelle;

  /// Selbsteinschätzung des Erzeugers: `hoch`, `mittel`, `niedrig`.
  final String sicherheit;

  /// Von Hand nachbearbeitet, bevor die Datei übernommen wurde.
  ///
  /// Steht **nicht** im Dateiformat und geht auch nicht über die Leitung: die
  /// Angabe gilt dem laufenden Vorgang, nicht dem Bestand. Sie hängt trotzdem
  /// am Eintrag und nicht an einer Zeilennummer daneben — Zeilen verschieben
  /// sich, sobald eine verworfen wird, und eine Merkliste aus Indizes wäre
  /// danach still falsch.
  final bool bearbeitet;

  const ImportMandantEintrag({
    this.anrede = '',
    this.vorname = '',
    this.nachname = '',
    this.strasseHausnummer = '',
    this.postleitzahl = '',
    this.ort = '',
    this.emailAdresse = '',
    this.telefonnummer = '',
    this.notiz = '',
    this.aktenOrdnernamen = const [],
    this.kennzeichen = const [],
    this.quelle = '',
    this.sicherheit = '',
    this.bearbeitet = false,
  });

  /// Derselbe Eintrag, als von Hand geändert vermerkt.
  ImportMandantEintrag alsBearbeitet() => ImportMandantEintrag(
    anrede: anrede,
    vorname: vorname,
    nachname: nachname,
    strasseHausnummer: strasseHausnummer,
    postleitzahl: postleitzahl,
    ort: ort,
    emailAdresse: emailAdresse,
    telefonnummer: telefonnummer,
    notiz: notiz,
    aktenOrdnernamen: aktenOrdnernamen,
    kennzeichen: kennzeichen,
    quelle: quelle,
    sicherheit: sicherheit,
    bearbeitet: true,
  );

  String get anzeigename => '$vorname $nachname'.trim();

  factory ImportMandantEintrag.fromJson(Map<String, dynamic> json) =>
      ImportMandantEintrag(
        anrede: json['anrede'] as String? ?? '',
        vorname: json['vorname'] as String? ?? '',
        nachname: json['nachname'] as String? ?? '',
        strasseHausnummer: json['strasseHausnummer'] as String? ?? '',
        postleitzahl: json['postleitzahl'] as String? ?? '',
        ort: json['ort'] as String? ?? '',
        emailAdresse: json['emailAdresse'] as String? ?? '',
        telefonnummer: json['telefonnummer'] as String? ?? '',
        notiz: json['notiz'] as String? ?? '',
        aktenOrdnernamen: _texte(json['aktenOrdnernamen']),
        kennzeichen: _texte(json['kennzeichen']),
        quelle: json['quelle'] as String? ?? '',
        sicherheit: json['sicherheit'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'anrede': anrede,
    'vorname': vorname,
    'nachname': nachname,
    'strasseHausnummer': strasseHausnummer,
    'postleitzahl': postleitzahl,
    'ort': ort,
    'emailAdresse': emailAdresse,
    'telefonnummer': telefonnummer,
    'notiz': notiz,
    'aktenOrdnernamen': aktenOrdnernamen,
    'kennzeichen': kennzeichen,
    'quelle': quelle,
    'sicherheit': sicherheit,
  };

  static List<String> _texte(Object? wert) =>
      wert is List ? wert.whereType<String>().toList() : const [];

  @override
  List<Object?> get props => [
    anrede,
    vorname,
    nachname,
    strasseHausnummer,
    postleitzahl,
    ort,
    emailAdresse,
    telefonnummer,
    notiz,
    aktenOrdnernamen,
    kennzeichen,
    quelle,
    sicherheit,
    bearbeitet,
  ];
}
