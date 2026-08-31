import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/referenz_teile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
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
/// (§3). Die meisten Felder sind optional, weil sie erst im Laufe des
/// Vorgangs entstehen (z. B. [antwort] kommt oft Tage nach der Anfrage).
class Vorgang extends Equatable {
  final String referenz;
  final DateTime angefragtAm;
  final VorgangStatus status;
  final Rechtsgebiet rechtsgebiet;

  /// Das Rechtsgebiet so, wie es gespeichert ist — vor der toleranten Abbildung
  /// durch [Rechtsgebiet.fromValue]. Nur die Anzeige im Register braucht das:
  /// Ein **leerer** Wert heisst „nie erfasst" und steht dort als
  /// [Rechtsgebiet.unbekannt], waehrend [rechtsgebiet] fuers Bearbeiten und
  /// Filtern weiterhin einen brauchbaren Wert liefert.
  ///
  /// Wird beim Bauen aus [rechtsgebiet] vorbelegt, wenn nichts uebergeben ist —
  /// sonst waere ein von Hand gebauter Vorgang nicht gleich seinem eigenen
  /// JSON-Rundlauf, und „nie erfasst" liesse sich nicht von „im Code gesetzt"
  /// unterscheiden.
  final String rechtsgebietRoh;

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

  /// Ein **angefangener**, noch nicht bestätigter Ausfüllstand — das Gegenstück
  /// zu [feldWerte]. Er überlebt Vorlagenwechsel, Neuladen und Abbruch und wird
  /// beim Wiedereinstieg **angeboten**, nie still eingesetzt. Null, wenn keiner
  /// offen ist; sobald aus den Werten ein Dokument entsteht, verdrängt der
  /// bestätigte Stand ihn ([VorgangRueckfluss]).
  final VorgangEntwurf? entwurf;

  /// Pfad des erzeugten Anspruchsschreibens bzw. der Ablageort in der Akte.
  final String? dokumentPfad;
  final String? aktenOrdner;

  final DateTime? abgeschlossenAm;

  Vorgang({
    required this.referenz,
    required this.angefragtAm,
    this.status = VorgangStatus.angefragt,
    this.rechtsgebiet = Rechtsgebiet.verkehrsrecht,
    String? rechtsgebietRoh,
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
    this.entwurf,
    this.dokumentPfad,
    this.aktenOrdner,
    this.abgeschlossenAm,
  }) : rechtsgebietRoh = rechtsgebietRoh ?? rechtsgebiet.value;

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

  /// Was in der vierten Registerspalte steht. Muss dieselbe Antwort geben wie
  /// `RechtsgebietAnzeige.Fuer` im Backend — sonst zeigt der Bildschirm ein
  /// anderes Sachgebiet an, als in der Register-Datei steht.
  String get rechtsgebietAnzeige => Rechtsgebiet.anzeige(rechtsgebietRoh);

  /// Bezeichnung „Mandant ./. Gegner" für die Registerspalte 3.
  ///
  /// Fehlt der eingetragene Gegner, tritt der Versicherer aus der
  /// Zentralruf-Antwort an seine Stelle. Muss dieselbe Antwort geben wie
  /// `RegisterZeilenBau.Gegenseite` im Backend — sonst zeigt der Bildschirm
  /// eine andere Gegenseite, als in der Register-Datei steht. Ein *leer*
  /// eingetragener Gegner zählt dabei wie gar keiner: Sonst hinge die
  /// Antwort daran, ob das Feld einmal angetippt wurde.
  String get parteienBezeichnung {
    final links = (mandantName ?? '').trim();
    final eingetragen = (gegner ?? '').trim();
    final rechts = eingetragen.isNotEmpty
        ? eingetragen
        : (antwort?.versichererName ?? '').trim();
    if (links.isEmpty && rechts.isEmpty) return '';
    return '$links ./. $rechts'.trim();
  }

  /// Der Sachbestand-Teil der Registerspalte 3 („Sachverhalt v. 20.06.2026").
  /// Getrennt von [parteienBezeichnung] abrufbar, damit die Registertabelle
  /// beide Teile auf breiten Fenstern nebeneinander setzen kann. Null, solange
  /// kein Unfalldatum erfasst ist.
  String? get registerSachbestand {
    final datum = (unfallDatum ?? '').trim();
    return datum.isEmpty ? null : 'Sachverhalt v. $datum';
  }

  /// Vollständiger Inhalt der Registerspalte 3: „Mandant ./. Gegner" mit dem
  /// Sachverhaltsdatum in der zweiten Zeile. Genutzt vom Sachgebiete-Register
  /// und vom Registerausschnitt der Startseite, damit beide Ansichten dieselbe
  /// Zeile zeigen.
  String get registerSachverhalt {
    final sachbestand = registerSachbestand;
    if (sachbestand == null) return parteienBezeichnung;
    return parteienBezeichnung.isEmpty
        ? sachbestand
        : '$parteienBezeichnung\n$sachbestand';
  }

  /// Ändert einzelne Felder. Alle Parameter außer [entwurf] sind nach dem
  /// Muster „null heißt: unverändert" gebaut — sie können deshalb nichts
  /// löschen, was in dieser Richtung (Daten wachsen an einem Vorgang) auch
  /// niemand braucht.
  ///
  /// [entwurf] ist die Ausnahme und deshalb ein Rückgabe-Aufruf: Ein Entwurf
  /// muss sich **löschen** lassen — „Verwerfen" ist die halbe Funktion, und mit
  /// `??` bliebe er stehen.
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
    VorgangEntwurf? Function()? entwurf,
    String? dokumentPfad,
    String? aktenOrdner,
    DateTime? abgeschlossenAm,
  }) {
    return Vorgang(
      referenz: referenz,
      angefragtAm: angefragtAm,
      status: status ?? this.status,
      rechtsgebiet: rechtsgebiet ?? this.rechtsgebiet,
      // Wird das Rechtsgebiet geaendert, zieht der Rohwert mit — sonst zeigte
      // das Register weiter den Stand von vor der Aenderung.
      rechtsgebietRoh: rechtsgebiet?.value ?? rechtsgebietRoh,
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
      entwurf: entwurf != null ? entwurf() : this.entwurf,
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
      entwurf: entwurf,
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
    rechtsgebietRoh,
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
    entwurf,
    dokumentPfad,
    aktenOrdner,
    abgeschlossenAm,
  ];
}
