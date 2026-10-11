import 'package:equatable/equatable.dart';

/// Was im Kopf einer Vollmacht steht (§4.11) — die Zeilen, die der Anwalt im
/// Dialog vor dem Druck sieht und korrigieren kann. Alles andere auf dem
/// Papier ist fester Text der Vorlage.
///
/// Die Bankverbindung fehlt mit Absicht: Sie bleibt für die Hand des
/// Mandanten frei und wird nirgends gespeichert (Datensparsamkeit — die
/// Kanzlei hat das Papier).
class VollmachtKopfdaten extends Equatable {
  final String vorname;
  final String nachname;
  final String strasse;
  final String plz;
  final String ort;
  final String telefon;
  final String email;
  final String unfalldatum;

  /// Das Tatdatum der Bußgeldsache (#171). Die App kennt es nicht, der Anwalt
  /// trägt es ein. Es geht **nicht** in den Auftrag an den Dienst: Aufs
  /// Papier kommt es nur über „wegen", in das die Vorbelegung es einsetzt.
  final String tatdatum;
  final String inSachen;
  final String wegen;

  const VollmachtKopfdaten({
    this.vorname = '',
    this.nachname = '',
    this.strasse = '',
    this.plz = '',
    this.ort = '',
    this.telefon = '',
    this.email = '',
    this.unfalldatum = '',
    this.tatdatum = '',
    this.inSachen = '',
    this.wegen = '',
  });

  static const VollmachtKopfdaten leer = VollmachtKopfdaten();

  /// „Vorname Nachname", wie er in „in Sachen" und „wegen" eingesetzt wird.
  String get name => '${vorname.trim()} ${nachname.trim()}'.trim();

  VollmachtKopfdaten copyWith({
    String? vorname,
    String? nachname,
    String? strasse,
    String? plz,
    String? ort,
    String? telefon,
    String? email,
    String? unfalldatum,
    String? tatdatum,
    String? inSachen,
    String? wegen,
  }) => VollmachtKopfdaten(
    vorname: vorname ?? this.vorname,
    nachname: nachname ?? this.nachname,
    strasse: strasse ?? this.strasse,
    plz: plz ?? this.plz,
    ort: ort ?? this.ort,
    telefon: telefon ?? this.telefon,
    email: email ?? this.email,
    unfalldatum: unfalldatum ?? this.unfalldatum,
    tatdatum: tatdatum ?? this.tatdatum,
    inSachen: inSachen ?? this.inSachen,
    wegen: wegen ?? this.wegen,
  );

  @override
  List<Object?> get props => [
    vorname,
    nachname,
    strasse,
    plz,
    ort,
    telefon,
    email,
    unfalldatum,
    tatdatum,
    inSachen,
    wegen,
  ];
}
