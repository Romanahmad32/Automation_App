import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/offene_anfrage.dart';
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

  /// Die aus der Zentralruf-Antwort übernommenen Daten, sobald vorhanden.
  final ZentralrufReplyData? antwort;

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
    this.antwort,
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
  }) {
    final teile = _ReferenzTeile.parse(referenz);
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

  factory Vorgang.fromJson(Map<String, dynamic> json) {
    final antwortJson = json['antwort'];
    return Vorgang(
      referenz: json['referenz'] as String? ?? '',
      angefragtAm:
          DateTime.tryParse(json['angefragtAm'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: VorgangStatus.fromValue(json['status'] as String?),
      rechtsgebiet: Rechtsgebiet.fromValue(json['rechtsgebiet'] as String?),
      laufendeNummer: (json['laufendeNummer'] as num?)?.toInt(),
      jahr: json['jahr'] as String?,
      abteilung: json['abteilung'] as String?,
      kennzeichen: json['kennzeichen'] as String?,
      mandantId: (json['mandantId'] as num?)?.toInt(),
      mandantName: json['mandantName'] as String?,
      gegner: json['gegner'] as String?,
      unfallDatum: json['unfallDatum'] as String?,
      antwort: antwortJson is Map<String, dynamic>
          ? ZentralrufReplyData.fromJson(antwortJson)
          : null,
      dokumentPfad: json['dokumentPfad'] as String?,
      aktenOrdner: json['aktenOrdner'] as String?,
      abgeschlossenAm: DateTime.tryParse(
        json['abgeschlossenAm'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'referenz': referenz,
    'angefragtAm': angefragtAm.toIso8601String(),
    'status': status.value,
    'rechtsgebiet': rechtsgebiet.value,
    'laufendeNummer': laufendeNummer,
    'jahr': jahr,
    'abteilung': abteilung,
    'kennzeichen': kennzeichen,
    'mandantId': mandantId,
    'mandantName': mandantName,
    'gegner': gegner,
    'unfallDatum': unfallDatum,
    'antwort': antwort?.toJson(),
    'dokumentPfad': dokumentPfad,
    'aktenOrdner': aktenOrdner,
    'abgeschlossenAm': abgeschlossenAm?.toIso8601String(),
  };

  Vorgang copyWith({
    VorgangStatus? status,
    Rechtsgebiet? rechtsgebiet,
    int? mandantId,
    String? mandantName,
    String? gegner,
    String? unfallDatum,
    ZentralrufReplyData? antwort,
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
      antwort: antwort ?? this.antwort,
      dokumentPfad: dokumentPfad ?? this.dokumentPfad,
      aktenOrdner: aktenOrdner ?? this.aktenOrdner,
      abgeschlossenAm: abgeschlossenAm ?? this.abgeschlossenAm,
    );
  }

  /// Referenzvergleich tolerant gegenüber Groß-/Kleinschreibung und
  /// Mehrfach-Leerzeichen (Mailprogramme brechen Zeilen gern um) — dieselbe
  /// Normalisierung wie im bisherigen OffeneAnfragenCubit.
  static bool gleicheReferenz(String a, String b) =>
      normalizeReferenz(a) == normalizeReferenz(b);

  static String normalizeReferenz(String referenz) =>
      referenz.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Überführt den alten Persistenzstand (Liste offener Anfragen + zuletzt
  /// übernommene Vorgangsdaten) in Vorgänge. Jede offene Anfrage wird zu einem
  /// Vorgang im Status „angefragt"; die letzten Antwortdaten werden dem Vorgang
  /// mit passender Referenz zugeordnet (Status „beantwortet") oder, falls keine
  /// passende Anfrage existiert, als eigener beantworteter Vorgang ergänzt.
  static List<Vorgang> migriereAusLegacy({
    required List<OffeneAnfrage> offeneAnfragen,
    ZentralrufReplyData? letzteAntwort,
  }) {
    final vorgaenge = [
      for (final anfrage in offeneAnfragen)
        Vorgang.ausAnfrage(
          referenz: anfrage.referenz,
          angefragtAm: anfrage.angefragtAm,
        ),
    ];

    final antwortReferenz = letzteAntwort?.referenz?.trim();
    if (letzteAntwort == null ||
        antwortReferenz == null ||
        antwortReferenz.isEmpty) {
      return vorgaenge;
    }

    final index = vorgaenge.indexWhere(
      (vorgang) => gleicheReferenz(vorgang.referenz, antwortReferenz),
    );
    if (index >= 0) {
      vorgaenge[index] = vorgaenge[index].mitAntwort(letzteAntwort);
    } else {
      vorgaenge.add(
        Vorgang.ausAnfrage(
          referenz: antwortReferenz,
          angefragtAm: DateTime.fromMillisecondsSinceEpoch(0),
        ).mitAntwort(letzteAntwort),
      );
    }
    return vorgaenge;
  }

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
      antwort: data,
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
    antwort,
    dokumentPfad,
    aktenOrdner,
    abgeschlossenAm,
  ];
}

/// Zerlegt eine Referenz „Nr/Jahr Abteilung_Kennzeichen" in ihre Bestandteile.
class _ReferenzTeile {
  final int? nummer;
  final String jahr;
  final String abteilung;
  final String kennzeichen;

  const _ReferenzTeile({
    required this.nummer,
    required this.jahr,
    required this.abteilung,
    required this.kennzeichen,
  });

  static final RegExp _muster = RegExp(r'^\s*(\d+)\s*/\s*(\d+)\s+(\S+)_(.+)$');

  static _ReferenzTeile? parse(String referenz) {
    final match = _muster.firstMatch(referenz);
    if (match == null) return null;
    return _ReferenzTeile(
      nummer: int.tryParse(match.group(1)!),
      jahr: match.group(2)!,
      abteilung: match.group(3)!,
      kennzeichen: match.group(4)!.trim(),
    );
  }
}
