import 'package:automation_app/features/mandanten/domain/entities/aktentyp.dart';
import 'package:automation_app/features/mandanten/domain/entities/arbeitspaket.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/domain/services/arbeitspaket_bauen.dart';

/// Bausteine für die Tests rund um das Arbeitspaket (`ArbeitspaketBauen`,
/// `ImportAehnlichkeit`, `Arbeitspaket.toJson`).
///
/// Attrappen braucht hier nichts: beide Dienste sind reine Rechnungen ohne
/// Repository dahinter. Was geteilt wird, sind die Bauhelfer — damit ein Test
/// über die Reihenfolge nicht zwischen zwanzig Feldern nach dem Ordnernamen
/// suchen lässt.
final DateTime erstellt = DateTime.utc(2026, 9, 5, 10, 12);

ArbeitspaketOrdner paketOrdner(
  String ordnername, {
  Aktentyp aktentyp = Aktentyp.verkehrsunfall,
  String vorname = '',
  String nachname = '',
  String? bekannterMandant,
  String? begruendung,
}) => ArbeitspaketOrdner(
  ordnername: ordnername,
  aktentyp: aktentyp,
  nameVorschlagVorname: vorname,
  nameVorschlagNachname: nachname,
  bekannterMandant: bekannterMandant,
  begruendung: begruendung,
);

/// Baut das Paket [nummer] aus [ordner] — mit denselben Rahmendaten, damit die
/// Tests nur den Unterschied zeigen, den sie prüfen.
Arbeitspaket bauePaket(
  List<ArbeitspaketOrdner> ordner, {
  int nummer = 1,
  int anzahl = ArbeitspaketBauen.vorgabeAnzahl,
  List<BekannterMandant> bekannteMandanten = const [],
}) => ArbeitspaketBauen.baue(
  offeneOrdner: ordner,
  bekannteMandanten: bekannteMandanten,
  paketNummer: nummer,
  stammordner: 'D:/Akten',
  anleitung: 'Ordne die Ordner den Mandanten zu.',
  erstelltAm: erstellt,
  anzahl: anzahl,
);

/// [anzahl] Ordner mit aufsteigend nummerierten Namen und **ohne**
/// Namensvorschlag — jeder bildet damit seine eigene Gruppe. Für die Frage, ob
/// der Bauer wirklich nur die vorderen nimmt.
List<ArbeitspaketOrdner> vieleOrdner(int anzahl) => [
  for (var i = 0; i < anzahl; i++)
    paketOrdner('VUnfallursache ${i.toString().padLeft(4, '0')}'),
];

/// Die Aktenarten, unter denen dieselbe Person mehrere Ordner haben kann —
/// genau der Fall, wegen dem ein Paket nach Mandanten schneidet.
const List<({String praefix, Aktentyp typ})> aktenarten = [
  (praefix: 'VUnfallursache', typ: Aktentyp.verkehrsunfall),
  (praefix: 'Strafsache', typ: Aktentyp.straf),
  (praefix: 'FamSache', typ: Aktentyp.familie),
];

/// Die [anzahl] Ordner **einer** Person (höchstens drei), jeder unter einer
/// anderen Aktenart — mit dem Namensvorschlag, den die Präsentation aus dem
/// Ordnernamen gewinnt.
List<ArbeitspaketOrdner> ordnerVonPerson(
  String vorname,
  String nachname, {
  int anzahl = 1,
}) => [
  for (var i = 0; i < anzahl; i++)
    paketOrdner(
      '${aktenarten[i].praefix} $vorname $nachname',
      aktentyp: aktenarten[i].typ,
      vorname: vorname,
      nachname: nachname,
    ),
];

/// Die Personen (Gruppenschlüssel) eines Pakets — womit sich prüfen lässt, dass
/// keine über zwei Pakete verteilt wird.
Set<String> personenIm(Arbeitspaket paket) => {
  for (final ordner in paket.ordner)
    ArbeitspaketBauen.gruppenschluessel(ordner),
};

/// Eine Zeile der Importdatei, wie sie der Ähnlichkeitshinweis vorfindet.
ImportMandantEintrag importZeile({
  String vorname = '',
  String nachname = '',
  List<String> kennzeichen = const [],
}) => ImportMandantEintrag(
  vorname: vorname,
  nachname: nachname,
  kennzeichen: kennzeichen,
);

/// Eine Vorschau aus [zeilen]: Datei und Bericht mit derselben Zeilenfolge —
/// so, wie beide aus einem Aufruf zurückkommen.
({MandantenImportDatei datei, ImportBericht bericht}) vorschau(
  List<ImportMandantEintrag> zeilen, {
  ImportArt art = ImportArt.neu,
}) => (
  datei: MandantenImportDatei(mandanten: zeilen),
  bericht: ImportBericht(
    eintraege: [
      for (var i = 0; i < zeilen.length; i++)
        ImportEintrag(zeile: i, anzeigename: zeilen[i].anzeigename, art: art),
    ],
  ),
);
