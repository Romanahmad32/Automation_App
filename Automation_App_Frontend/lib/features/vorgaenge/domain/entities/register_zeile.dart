import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_jahrgang.dart';
import 'package:equatable/equatable.dart';

/// Woher eine Registerzeile stammt. Muss zu `RegisterQuellen` im Backend
/// passen — die Werte stehen als Zeichenkette in der Antwort, nicht als Zahl.
abstract final class RegisterQuellen {
  static const String vorgang = 'vorgang';
  static const String historie = 'historie';
}

/// Wie sicher sich der Erzeuger der Importdatei bei einer historischen Zeile
/// war. Gegenstück zu `RegisterSicherheiten` im Backend.
///
/// Die Oberfläche sagt dieselben Wörter wie der Mandanten-Import
/// („sicher / unsicher / sehr unsicher") — zwei Wortleitern für dieselbe
/// Selbsteinschätzung wären eine zu viel.
abstract final class RegisterSicherheiten {
  static const String hoch = 'hoch';
  static const String mittel = 'mittel';
  static const String niedrig = 'niedrig';

  /// Wortlaut für den Bildschirm. Alles, was nicht ausdrücklich [hoch] sagt,
  /// gilt als prüfenswert — deshalb ist „ohne Angabe" der Rückfall.
  static String bezeichnung(String? wert) =>
      switch ((wert ?? '').trim().toLowerCase()) {
        RegisterSicherheiten.hoch => 'sicher',
        RegisterSicherheiten.mittel => 'unsicher',
        RegisterSicherheiten.niedrig => 'sehr unsicher',
        _ => 'ohne Angabe',
      };
}

/// Eine Zeile des Sachgebiete-Registers (§6.2), **gleich welcher Herkunft** —
/// ein laufender Vorgang der App oder eine übernommene Zeile aus dem
/// Registerbuch der Kanzlei.
///
/// Gebaut wird sie im Backend (`RegisterZeilenBau`), nicht hier. Das ist der
/// Kern von Issue #109: Vorher leitete die Ansicht ihre Zellen aus [Vorgang]
/// ab und die Word-/PDF-Datei ihre aus derselben Rechnung im Dienst — zwei
/// Quellen, die auseinanderlaufen konnten, ohne dass es jemandem auffiel.
/// Jetzt gibt es eine Quelle, und der Bildschirm zeigt, was in der Datei
/// steht. Nur [RegisterZeile.ausVorgang] rechnet noch selbst — dieselbe
/// Gefahr im Kleinen bewacht `vorgang_jahrgang_test.dart`.
class RegisterZeile extends Equatable {
  /// Vierstelliger Jahrgang („2019") — die Zwischenüberschrift, unter der die
  /// Zeile steht. Nie leer, damit keine Zeile aus der Gliederung fällt.
  final String jahr;

  /// Die laufende Nummer im Jahrgang; null, solange keine vergeben ist. Ein
  /// Vorgang bekommt sie erst mit dem Abschluss.
  final int? laufendeNummer;

  /// Zeichen samt Abteilung („01/26 C03") — nie die volle Referenz (§4.2).
  final String zeichen;

  /// Spalte „Sache": „Mandant ./. Gegner" (Form A) oder „Sachart Mandant"
  /// (Form B, wenn es keine Gegenseite gibt).
  final String parteien;

  /// „Unfall v. 28.12.2025"; leer, wenn nichts erfasst ist.
  final String sachbestand;

  final String rechtsgebiet;

  /// Ob der Vorgang abgeschlossen ist. Historische Zeilen sind es immer.
  final bool abgeschlossen;

  /// [RegisterQuellen.vorgang] oder [RegisterQuellen.historie].
  final String quelle;

  /// Schlüssel der historischen Zeile — nur bei Quelle „historie". Er ist die
  /// Adresse des Bearbeiten-Dialogs (`PUT /api/RegisterHistorie/{id}`).
  final int? historieId;

  /// Die Referenz des Vorgangs — nur bei Quelle „vorgang".
  final String? vorgangReferenz;

  final String sicherheit;

  /// Was an der historischen Zeile auffiel (Widerspruch, unbekanntes Kürzel).
  /// Leer bei Vorgängen der App.
  final List<String> befunde;

  const RegisterZeile({
    required this.jahr,
    required this.zeichen,
    this.laufendeNummer,
    this.parteien = '',
    this.sachbestand = '',
    this.rechtsgebiet = '',
    this.abgeschlossen = false,
    this.quelle = RegisterQuellen.vorgang,
    this.historieId,
    this.vorgangReferenz,
    this.sicherheit = RegisterSicherheiten.hoch,
    this.befunde = const [],
  });

  /// Ob die Zeile aus dem übernommenen Registerbuch stammt. Sie lässt sich
  /// nicht öffnen, sondern nur berichtigen — und trägt am Bildschirm immer den
  /// Status „Historie", damit sie von einem Vorgang der App unterscheidbar
  /// bleibt.
  bool get istHistorie => quelle == RegisterQuellen.historie;

  /// Ob die Zeile einen zweiten Blick verdient: Es gibt einen Befund, oder der
  /// Erzeuger der Datei war sich seiner Zerlegung nicht sicher.
  bool get zuPruefen =>
      befunde.isNotEmpty || sicherheit != RegisterSicherheiten.hoch;

  /// Die Selbsteinschätzung in Worten („sicher", „sehr unsicher").
  String get sicherheitText => RegisterSicherheiten.bezeichnung(sicherheit);

  /// Was in der vierten Spalte steht — ein nie erfasstes Sachgebiet wird zum
  /// Strich und nicht stillschweigend zu „Verkehrsrecht".
  String get rechtsgebietAnzeige => RechtsgebietWert.anzeige(rechtsgebiet);

  /// Beide Teile der Spalte „Sache" untereinander, wie auf schmalen Fenstern
  /// und im Word-Register.
  String get sacheUndSachbestand {
    if (sachbestand.isEmpty) return parteien;
    return parteien.isEmpty ? sachbestand : '$parteien\n$sachbestand';
  }

  factory RegisterZeile.fromJson(Map<String, dynamic> json) => RegisterZeile(
    jahr: json['jahr'] as String? ?? '',
    laufendeNummer: (json['laufendeNummer'] as num?)?.toInt(),
    zeichen: json['zeichen'] as String? ?? '',
    parteien: json['parteien'] as String? ?? '',
    sachbestand: json['sachbestand'] as String? ?? '',
    rechtsgebiet: json['rechtsgebiet'] as String? ?? '',
    abgeschlossen: json['abgeschlossen'] as bool? ?? false,
    quelle: json['quelle'] as String? ?? RegisterQuellen.vorgang,
    historieId: (json['historieId'] as num?)?.toInt(),
    vorgangReferenz: json['vorgangReferenz'] as String?,
    sicherheit: json['sicherheit'] as String? ?? RegisterSicherheiten.hoch,
    befunde: (json['befunde'] as List?)?.cast<String>() ?? const [],
  );

  /// Die Zeilen aus dem Umschlag `RegisterZeilenDto`. Ein Umschlag statt einer
  /// blanken Liste, damit später eine Gesamtzahl danebentreten kann, ohne dass
  /// der Vertrag seine Form ändert.
  static List<RegisterZeile> listeAusJson(Map<String, dynamic> json) => [
    for (final zeile in (json['zeilen'] as List? ?? const []))
      RegisterZeile.fromJson(zeile as Map<String, dynamic>),
  ];

  /// Baut eine Zeile aus einem bereits geladenen [Vorgang].
  ///
  /// **Nur für die Startseiten-Karte**, die den Vorgangsbestand ohnehin im
  /// Speicher hat und keinen zweiten Abruf rechtfertigt. Die Registeransicht
  /// selbst holt ihre Zeilen aus dem Backend — sie ist die Ansicht, die mit
  /// der Kanzleidatei übereinstimmen muss, und dort zählt eine Quelle.
  factory RegisterZeile.ausVorgang(Vorgang vorgang) => RegisterZeile(
    jahr: VorgangJahrgang.fuer(vorgang),
    laufendeNummer: vorgang.laufendeNummer,
    zeichen: vorgang.zeichen,
    parteien: vorgang.parteienBezeichnung,
    sachbestand: vorgang.registerSachbestand ?? '',
    rechtsgebiet: vorgang.rechtsgebiet,
    abgeschlossen: vorgang.status == VorgangStatus.versendet,
    vorgangReferenz: vorgang.referenz,
  );

  @override
  List<Object?> get props => [
    jahr,
    laufendeNummer,
    zeichen,
    parteien,
    sachbestand,
    rechtsgebiet,
    abgeschlossen,
    quelle,
    historieId,
    vorgangReferenz,
    sicherheit,
    befunde,
  ];
}
