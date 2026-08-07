import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/referenz_teile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:equatable/equatable.dart';

/// Ein Vorgang ist die gemeinsame Klammer über den gesamten Lebenszyklus eines
/// Auftrags: Zentralruf-Anfrage → Antwort → Anspruchsschreiben → Ablage →
/// Versand. Er bündelt die bisher verstreuten Daten (Mandant, Referenz,
/// Antwortdaten, Dokument) an einer Stelle, damit die Features sie
/// wiederverwenden statt sie mehrfach zu erfassen.
///
/// Identität ist die [referenz] (`Nr/Jahr Abteilung_Kennzeichen`); über sie
/// wird eine eingehende Zentralruf-Antwort dem richtigen Vorgang zugeordnet
/// (Req. 3.3). Die meisten Felder sind optional, weil sie erst im Laufe des
/// Vorgangs entstehen (z. B. [antwort] kommt oft Tage nach der Anfrage).
class Vorgang extends Equatable {
  final String referenz;
  final DateTime angefragtAm;
  final VorgangStatus status;
  final Rechtsgebiet rechtsgebiet;

  /// Bestandteile der Referenz, beim Anlegen aus [referenz] geparst.
  final int? laufendeNummer;
  final String? jahr;
  final String? abteilung;
  final String? kennzeichen;

  /// Verknüpfung ins Mandantenregister (`mandanten.json`). Null, solange der
  /// Vorgang noch keinem erfassten Mandanten zugeordnet ist.
  final int? mandantId;

  /// Schnappschuss des Mandantennamens zum Zeitpunkt der Zuordnung — für die
  /// Anzeige und die Registerzeile, unabhängig von späteren Änderungen am
  /// Mandanten.
  final String? mandantName;

  /// Gegner/gegnerische Versicherung (für „Name ./. Gegner" im Register).
  final String? gegner;
  final String? unfallDatum;

  /// Kfz-Kennzeichen des Mandanten/Geschädigten (eigenes Fahrzeug, mit
  /// Bindestrich). Getrennt vom [kennzeichen] (= Kennzeichen des Gegners aus der
  /// Referenz). Null, solange nicht erfasst.
  final String? geschaedigtenKennzeichen;

  /// Angaben zum Unfallhergang für die spätere Akten-/Schreibenerstellung.
  /// Optional; nur bei Verkehrsunfall-Vorgängen befüllt.
  final String? unfallort;
  final String? unfalluhrzeit;
  final String? polizeiVorgangsnummer;

  /// Die aus der Zentralruf-Antwort übernommenen Daten, sobald vorhanden.
  final ZentralrufReplyData? antwort;

  /// Die zuletzt im Word-Assistenten ausgefüllten Formularfelder
  /// (Label → Wert). Beim nächsten Schreiben zum selben Vorgang werden sie
  /// mit Vorrang vor der Heuristik vorbelegt — der Anwalt hat sie ja bereits
  /// bestätigt. Null, solange noch kein Dokument erzeugt wurde.
  final Map<String, String>? feldWerte;

  /// Die zuletzt erfasste Schadensaufstellung (nur Vorlagen „mit Auflistung"),
  /// für die Wiederverwendung bei Folge-/Korrekturschreiben.
  final DamageListing? schadensaufstellung;

  /// Pfad des erzeugten Anspruchsschreibens bzw. der Ablageort in der Akte.
  final String? dokumentPfad;
  final String? aktenOrdner;

  final DateTime? abgeschlossenAm;

  const Vorgang({
    required this.referenz,
    required this.angefragtAm,
    this.status = VorgangStatus.angefragt,
    this.rechtsgebiet = Rechtsgebiet.verkehrsrecht,
    this.laufendeNummer,
    this.jahr,
    this.abteilung,
    this.kennzeichen,
    this.mandantId,
    this.mandantName,
    this.gegner,
    this.unfallDatum,
    this.geschaedigtenKennzeichen,
    this.unfallort,
    this.unfalluhrzeit,
    this.polizeiVorgangsnummer,
    this.antwort,
    this.feldWerte,
    this.schadensaufstellung,
    this.dokumentPfad,
    this.aktenOrdner,
    this.abgeschlossenAm,
  });

  /// Legt einen Vorgang aus einer gestarteten Zentralruf-Anfrage an: parst die
  /// Referenz in ihre Bestandteile und setzt den Status auf „angefragt".
  factory Vorgang.ausAnfrage({
    required String referenz,
    required DateTime angefragtAm,
    Rechtsgebiet rechtsgebiet = Rechtsgebiet.verkehrsrecht,
    int? mandantId,
    String? mandantName,
    String? unfallDatum,
    String? geschaedigtenKennzeichen,
    String? unfallort,
    String? unfalluhrzeit,
    String? polizeiVorgangsnummer,
  }) {
    final teile = ReferenzTeile.parse(referenz);
    return Vorgang(
      referenz: referenz.trim(),
      angefragtAm: angefragtAm,
      rechtsgebiet: rechtsgebiet,
      laufendeNummer: teile?.nummer,
      jahr: teile?.jahr,
      abteilung: teile?.abteilung,
      kennzeichen: teile?.kennzeichen,
      mandantId: mandantId,
      mandantName: mandantName,
      unfallDatum: unfallDatum,
      geschaedigtenKennzeichen: geschaedigtenKennzeichen,
      unfallort: unfallort,
      unfalluhrzeit: unfalluhrzeit,
      polizeiVorgangsnummer: polizeiVorgangsnummer,
    );
  }

  /// Aktenzeichen ohne Kennzeichen-Teil für die Registerspalte 2 (z. B.
  /// „144/26 C03"). Fällt auf die volle Referenz zurück, wenn die Bestandteile
  /// fehlen.
  String get aktenzeichen {
    if (laufendeNummer != null && jahr != null && abteilung != null) {
      return '$laufendeNummer/$jahr $abteilung';
    }
    return referenz;
  }

  /// Bezeichnung „Mandant ./. Gegner" für die Registerspalte 3.
  String get parteienBezeichnung {
    final links = (mandantName ?? '').trim();
    final rechts = (gegner ?? antwort?.versichererName ?? '').trim();
    if (links.isEmpty && rechts.isEmpty) return '';
    return '$links ./. $rechts'.trim();
  }

  /// Vollständiger Inhalt der Registerspalte 3: „Mandant ./. Gegner" mit dem
  /// Sachverhaltsdatum in der zweiten Zeile. Genutzt vom Sachgebiete-Register
  /// und vom Registerausschnitt der Startseite, damit beide Ansichten dieselbe
  /// Zeile zeigen.
  String get registerSachverhalt {
    final datum = (unfallDatum ?? '').trim();
    if (datum.isEmpty) return parteienBezeichnung;
    final sachbestand = 'Sachverhalt v. $datum';
    return parteienBezeichnung.isEmpty
        ? sachbestand
        : '$parteienBezeichnung\n$sachbestand';
  }

  Vorgang copyWith({
    VorgangStatus? status,
    Rechtsgebiet? rechtsgebiet,
    int? mandantId,
    String? mandantName,
    String? gegner,
    String? unfallDatum,
    String? geschaedigtenKennzeichen,
    String? unfallort,
    String? unfalluhrzeit,
    String? polizeiVorgangsnummer,
    ZentralrufReplyData? antwort,
    Map<String, String>? feldWerte,
    DamageListing? schadensaufstellung,
    String? dokumentPfad,
    String? aktenOrdner,
    DateTime? abgeschlossenAm,
  }) {
    return Vorgang(
      referenz: referenz,
      angefragtAm: angefragtAm,
      status: status ?? this.status,
      rechtsgebiet: rechtsgebiet ?? this.rechtsgebiet,
      laufendeNummer: laufendeNummer,
      jahr: jahr,
      abteilung: abteilung,
      kennzeichen: kennzeichen,
      mandantId: mandantId ?? this.mandantId,
      mandantName: mandantName ?? this.mandantName,
      gegner: gegner ?? this.gegner,
      unfallDatum: unfallDatum ?? this.unfallDatum,
      geschaedigtenKennzeichen:
          geschaedigtenKennzeichen ?? this.geschaedigtenKennzeichen,
      unfallort: unfallort ?? this.unfallort,
      unfalluhrzeit: unfalluhrzeit ?? this.unfalluhrzeit,
      polizeiVorgangsnummer:
          polizeiVorgangsnummer ?? this.polizeiVorgangsnummer,
      antwort: antwort ?? this.antwort,
      feldWerte: feldWerte ?? this.feldWerte,
      schadensaufstellung: schadensaufstellung ?? this.schadensaufstellung,
      dokumentPfad: dokumentPfad ?? this.dokumentPfad,
      aktenOrdner: aktenOrdner ?? this.aktenOrdner,
      abgeschlossenAm: abgeschlossenAm ?? this.abgeschlossenAm,
    );
  }

  /// Referenzvergleich tolerant gegenüber Groß-/Kleinschreibung und
  /// Mehrfach-Leerzeichen (Mailprogramme brechen Zeilen gern um).
  static bool gleicheReferenz(String a, String b) =>
      normalizeReferenz(a) == normalizeReferenz(b);

  static String normalizeReferenz(String referenz) =>
      referenz.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Hängt die übernommenen Antwortdaten an und schaltet den Status auf
  /// „beantwortet" weiter. Übernimmt Gegner, Unfalldatum und (falls noch nicht
  /// gesetzt) das Kennzeichen aus der Antwort.
  Vorgang mitAntwort(ZentralrufReplyData data) {
    return Vorgang(
      referenz: referenz,
      angefragtAm: angefragtAm,
      status: status == VorgangStatus.angefragt
          ? VorgangStatus.beantwortet
          : status,
      rechtsgebiet: rechtsgebiet,
      laufendeNummer: laufendeNummer,
      jahr: jahr,
      abteilung: abteilung,
      kennzeichen: kennzeichen ?? data.kennzeichen,
      mandantId: mandantId,
      mandantName: mandantName,
      gegner: gegner ?? data.versichererName,
      unfallDatum: unfallDatum ?? data.unfallDatum,
      geschaedigtenKennzeichen: geschaedigtenKennzeichen,
      unfallort: unfallort,
      unfalluhrzeit: unfalluhrzeit,
      polizeiVorgangsnummer: polizeiVorgangsnummer,
      antwort: data,
      feldWerte: feldWerte,
      schadensaufstellung: schadensaufstellung,
      dokumentPfad: dokumentPfad,
      aktenOrdner: aktenOrdner,
      abgeschlossenAm: abgeschlossenAm,
    );
  }

  @override
  List<Object?> get props => [
    referenz,
    angefragtAm,
    status,
    rechtsgebiet,
    laufendeNummer,
    jahr,
    abteilung,
    kennzeichen,
    mandantId,
    mandantName,
    gegner,
    unfallDatum,
    geschaedigtenKennzeichen,
    unfallort,
    unfalluhrzeit,
    polizeiVorgangsnummer,
    antwort,
    feldWerte,
    schadensaufstellung,
    dokumentPfad,
    aktenOrdner,
    abgeschlossenAm,
  ];
}
