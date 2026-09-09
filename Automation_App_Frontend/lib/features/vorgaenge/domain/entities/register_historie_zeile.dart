import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:equatable/equatable.dart';

/// Eine gespeicherte Zeile der Registerhistorie in ihren **Einzelfeldern** —
/// so, wie der Bearbeiten-Dialog sie braucht und wie
/// `PUT /api/RegisterHistorie/{id}` sie zurückerwartet.
///
/// Das Gegenstück zur [RegisterZeile]: Die trägt die *Anzeigeform* (Zeichen,
/// „Sache", „Sachbestand" zusammengesetzt) und ist die Zelle der Tabelle;
/// diese hier trägt den Rohstand und wird erst beim Öffnen des Dialogs geholt
/// (`GET /api/RegisterHistorie/{id}`). Ohne sie müsste die Oberfläche die
/// Anzeigeform zurückrechnen und dabei raten, wo „Bußgeldsache Erika
/// Musterfrau" die Sachart aufhört und der Name anfängt.
///
/// [freitext] geht bewusst mit über die Leitung: Er ist der Beleg, gegen den
/// der Anwalt eine Berichtigung liest. [kennung] ebenso — sie ist die stabile
/// Referenz (§7.2), während [id] eine Zählnummer der Datenbank bleibt.
class RegisterHistorieZeile extends Equatable {
  final int id;
  final String kennung;
  final int jahr;
  final int laufendeNummer;

  /// Zusatz an der Nummer, etwa das „-I" in „10/19-I". Leer im Regelfall.
  final String nummerZusatz;

  final String aktenzeichen;
  final String abteilung;

  /// „Bußgeldsache", „Strafsache" — leer, wo es eine Gegenseite gibt.
  final String sachart;

  final String mandant;
  final String gegner;
  final String sachbestand;
  final String unfalldatum;
  final String rechtsgebiet;

  /// Die Freitextzelle des Registerbuchs, unverändert. Der Beleg.
  final String freitext;

  final String sicherheit;

  /// Was die App an der Zeile beanstandet (Widerspruch, unbekanntes Kürzel).
  final List<String> befunde;

  /// Was der Erzeuger der Importdatei angemerkt hat.
  final List<String> hinweise;

  /// Verknüpfung ins Mandantenregister. Bleibt vorerst leer — die Zuordnung
  /// historischer Zeilen zu Mandanten ist ein eigener Schritt.
  final int? mandantId;

  /// Wann der Anwalt die Zeile zuletzt berichtigt hat; null, solange sie steht,
  /// wie sie eingelesen wurde.
  final DateTime? geaendertAm;

  const RegisterHistorieZeile({
    required this.id,
    this.kennung = '',
    this.jahr = 0,
    this.laufendeNummer = 0,
    this.nummerZusatz = '',
    this.aktenzeichen = '',
    this.abteilung = '',
    this.sachart = '',
    this.mandant = '',
    this.gegner = '',
    this.sachbestand = '',
    this.unfalldatum = '',
    this.rechtsgebiet = '',
    this.freitext = '',
    this.sicherheit = RegisterSicherheiten.hoch,
    this.befunde = const [],
    this.hinweise = const [],
    this.mandantId,
    this.geaendertAm,
  });

  /// Die Selbsteinschätzung der Übernahme in Worten („sicher", „sehr
  /// unsicher") — dieselbe Wortleiter wie am Chip in der Tabelle.
  String get sicherheitText => RegisterSicherheiten.bezeichnung(sicherheit);

  factory RegisterHistorieZeile.fromJson(Map<String, dynamic> json) {
    final geaendert = json['geaendertAm'] as String?;
    return RegisterHistorieZeile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kennung: json['kennung'] as String? ?? '',
      jahr: (json['jahr'] as num?)?.toInt() ?? 0,
      laufendeNummer: (json['laufendeNummer'] as num?)?.toInt() ?? 0,
      nummerZusatz: json['nummerZusatz'] as String? ?? '',
      aktenzeichen: json['aktenzeichen'] as String? ?? '',
      abteilung: json['abteilung'] as String? ?? '',
      sachart: json['sachart'] as String? ?? '',
      mandant: json['mandant'] as String? ?? '',
      gegner: json['gegner'] as String? ?? '',
      sachbestand: json['sachbestand'] as String? ?? '',
      unfalldatum: json['unfalldatum'] as String? ?? '',
      rechtsgebiet: json['rechtsgebiet'] as String? ?? '',
      freitext: json['freitext'] as String? ?? '',
      sicherheit: json['sicherheit'] as String? ?? RegisterSicherheiten.hoch,
      befunde: (json['befunde'] as List?)?.cast<String>() ?? const [],
      hinweise: (json['hinweise'] as List?)?.cast<String>() ?? const [],
      mandantId: (json['mandantId'] as num?)?.toInt(),
      // `toLocal()` wie überall an der Grenze zum Dienst: er sendet mit
      // Zeitzonenversatz, angezeigt wird Ortszeit.
      geaendertAm: geaendert == null
          ? null
          : DateTime.tryParse(geaendert)?.toLocal(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    kennung,
    jahr,
    laufendeNummer,
    nummerZusatz,
    aktenzeichen,
    abteilung,
    sachart,
    mandant,
    gegner,
    sachbestand,
    unfalldatum,
    rechtsgebiet,
    freitext,
    sicherheit,
    befunde,
    hinweise,
    mandantId,
    geaendertAm,
  ];
}
