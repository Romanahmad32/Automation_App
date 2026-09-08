import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_aenderung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_historie_repository.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_spiegel_repository.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_zeilen_repository.dart';

/// Bausteine für die Tests rund um die Registeransicht (§6.2).
///
/// Attrappen von Hand statt eines Mocking-Pakets: Die beiden Ports haben
/// zusammen drei Methoden, und eine handgeschriebene Attrappe sagt im Test
/// selbst, was sie zurückgibt und was sie sich gemerkt hat.

/// Eine Zeile aus einem Vorgang der App.
RegisterZeile vorgangsZeile({
  String jahr = '2026',
  int? nummer = 1,
  String zeichen = '01/26 C03',
  String parteien = 'Mustermann, Max ./. HUK-COBURG',
  String sachbestand = 'Sachverhalt v. 20.06.2026',
  String rechtsgebiet = 'Verkehrsrecht',
  bool abgeschlossen = true,
  String referenz = '01/26 C03_HG-E 1427',
}) => RegisterZeile(
  jahr: jahr,
  laufendeNummer: nummer,
  zeichen: zeichen,
  parteien: parteien,
  sachbestand: sachbestand,
  rechtsgebiet: rechtsgebiet,
  abgeschlossen: abgeschlossen,
  vorgangReferenz: referenz,
);

/// Eine Zeile aus dem übernommenen Registerbuch.
RegisterZeile historieZeile({
  String jahr = '2019',
  int? nummer = 10,
  String zeichen = '10/19-I C02',
  String parteien = 'Bernd Mustermann ./. Beate Mustermann',
  String sachbestand = 'Ehescheidung',
  String rechtsgebiet = 'Familienrecht',
  int historieId = 7,
  String sicherheit = RegisterSicherheiten.hoch,
  List<String> befunde = const [],
}) => RegisterZeile(
  jahr: jahr,
  laufendeNummer: nummer,
  zeichen: zeichen,
  parteien: parteien,
  sachbestand: sachbestand,
  rechtsgebiet: rechtsgebiet,
  abgeschlossen: true,
  quelle: RegisterQuellen.historie,
  historieId: historieId,
  sicherheit: sicherheit,
  befunde: befunde,
);

/// Liefert die vorgegebenen Zeilen; merkt sich, wie oft sie geholt wurden.
class FakeRegisterZeilen implements RegisterZeilenRepository {
  List<RegisterZeile> zeilen;

  /// Wird geworfen statt geliefert, wenn gesetzt — der Weg, den Fehlerpfad zu
  /// prüfen.
  Exception? fehler;

  int abrufe = 0;

  FakeRegisterZeilen({this.zeilen = const [], this.fehler});

  @override
  Future<List<RegisterZeile>> ladeZeilen({int? jahrgang}) async {
    abrufe++;
    if (fehler != null) throw fehler!;
    return zeilen;
  }
}

/// Der Rohstand einer gespeicherten Zeile, wie `GET /api/RegisterHistorie/{id}`
/// ihn liefert.
RegisterHistorieZeile rohZeile({
  int id = 7,
  String abteilung = 'C02',
  String sachart = '',
  String mandant = 'Bernd Mustermann',
  String gegner = 'Beate Mustermann',
  String sachbestand = 'Ehescheidung',
  String unfalldatum = '',
  String rechtsgebiet = 'Familienrecht',
  String freitext =
      '10/19-I C 02 Bernd Mustermann ./. Beate Mustermann  '
      'Ehescheidung',
  String sicherheit = RegisterSicherheiten.niedrig,
  List<String> befunde = const [],
  List<String> hinweise = const [],
}) => RegisterHistorieZeile(
  id: id,
  kennung: 'f1e2d3c4',
  jahr: 2019,
  laufendeNummer: 10,
  nummerZusatz: '-I',
  aktenzeichen: '10/19-I',
  abteilung: abteilung,
  sachart: sachart,
  mandant: mandant,
  gegner: gegner,
  sachbestand: sachbestand,
  unfalldatum: unfalldatum,
  rechtsgebiet: rechtsgebiet,
  freitext: freitext,
  sicherheit: sicherheit,
  befunde: befunde,
  hinweise: hinweise,
);

/// Liefert den vorgegebenen Stand, den Rohstand einer Zeile — und merkt sich
/// die Berichtigungen.
class FakeRegisterHistorie implements RegisterHistorieRepository {
  RegisterHistorieStand stand;

  /// Was `lade` zurückgibt; null lässt den Abruf scheitern.
  RegisterHistorieZeile? roh;

  Exception? fehler;

  /// Die Kennungen, zu denen `lade` gerufen wurde.
  final List<int> geladen = [];

  /// Was `aendere` bekommen hat, in der Reihenfolge der Aufrufe.
  final List<({int id, RegisterHistorieAenderung aenderung})> geaendert = [];

  FakeRegisterHistorie({
    this.stand = RegisterHistorieStand.leer,
    this.roh,
    this.fehler,
  });

  @override
  Future<RegisterHistorieStand> ladeStand() async => stand;

  @override
  Future<RegisterHistorieZeile> lade(int id) async {
    geladen.add(id);
    final zeile = roh;
    if (zeile == null) throw Exception('404');
    return zeile;
  }

  @override
  Future<void> aendere(int id, RegisterHistorieAenderung aenderung) async {
    if (fehler != null) throw fehler!;
    geaendert.add((id: id, aenderung: aenderung));
  }
}

/// Tut nichts — die Spiegelleiste am Fuß der Ansicht braucht nur einen Stand,
/// damit die Seite überhaupt aufgeht.
class FakeRegisterSpiegel implements RegisterSpiegelRepository {
  @override
  Future<RegisterSpiegelErgebnis> exportiere({bool erzwingen = true}) async =>
      RegisterSpiegelErgebnis.unbekannt;

  @override
  Future<RegisterSpiegelErgebnis> ladeStand() async =>
      RegisterSpiegelErgebnis.unbekannt;
}
