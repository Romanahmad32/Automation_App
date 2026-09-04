import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_entwurf.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/word_automation/domain/entities/damage_listing.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';

/// JSON-Abbildung des [Vorgang]s (Backend-DTO ↔ Entität), ausgelagert aus der
/// Entität, damit diese die fachlichen Ableitungen behält und lesbar bleibt.
/// Die Feldnamen entsprechen 1:1 dem camelCase-DTO des Backends (`VorgangDto`).
Vorgang vorgangAusJson(Map<String, dynamic> json) {
  final antwortJson = json['antwort'];
  final feldWerteJson = json['feldWerte'];
  final aufstellungJson = json['schadensaufstellung'];
  final entwurfJson = json['entwurf'];
  return Vorgang(
    referenz: json['referenz'] as String? ?? '',
    angefragtAm:
        DateTime.tryParse(json['angefragtAm'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    status: VorgangStatus.fromValue(json['status'] as String?),
    // Wortgetreu, ohne Umbiegen: Ein unbekannter oder leerer gespeicherter
    // Wert bleibt erhalten und wird beim Zurückschreiben nicht verändert.
    rechtsgebiet: json['rechtsgebiet'] as String? ?? '',
    laufendeNummer: (json['laufendeNummer'] as num?)?.toInt(),
    jahr: json['jahr'] as String?,
    abteilung: json['abteilung'] as String?,
    kennzeichen: json['kennzeichen'] as String?,
    mandantId: (json['mandantId'] as num?)?.toInt(),
    mandantName: json['mandantName'] as String?,
    gegner: json['gegner'] as String?,
    unfallDatum: json['unfallDatum'] as String?,
    geschaedigtenKennzeichen: json['geschaedigtenKennzeichen'] as String?,
    unfallort: json['unfallort'] as String?,
    unfalluhrzeit: json['unfalluhrzeit'] as String?,
    polizeiVorgangsnummer: json['polizeiVorgangsnummer'] as String?,
    antwort: antwortJson is Map<String, dynamic>
        ? ZentralrufReplyData.fromJson(antwortJson)
        : null,
    feldWerte: feldWerteJson is Map<String, dynamic>
        ? {
            for (final eintrag in feldWerteJson.entries)
              if (eintrag.value is String) eintrag.key: eintrag.value as String,
          }
        : null,
    schadensaufstellung: aufstellungJson is Map<String, dynamic>
        ? DamageListing.fromJson(aufstellungJson)
        : null,
    entwurf: entwurfJson is Map<String, dynamic>
        ? VorgangEntwurf.fromJson(entwurfJson)
        : null,
    schreibenNummer: (json['schreibenNummer'] as num?)?.toInt(),
    dokumentPfad: json['dokumentPfad'] as String?,
    aktenOrdner: json['aktenOrdner'] as String?,
    abgeschlossenAm: DateTime.tryParse(
      json['abgeschlossenAm'] as String? ?? '',
    ),
  );
}

extension VorgangAlsJson on Vorgang {
  Map<String, dynamic> toJson() => {
    'referenz': referenz,
    'angefragtAm': angefragtAm.toIso8601String(),
    'status': status.value,
    'rechtsgebiet': rechtsgebiet,
    'laufendeNummer': laufendeNummer,
    'jahr': jahr,
    'abteilung': abteilung,
    'kennzeichen': kennzeichen,
    'mandantId': mandantId,
    'mandantName': mandantName,
    'gegner': gegner,
    'unfallDatum': unfallDatum,
    'geschaedigtenKennzeichen': geschaedigtenKennzeichen,
    'unfallort': unfallort,
    'unfalluhrzeit': unfalluhrzeit,
    'polizeiVorgangsnummer': polizeiVorgangsnummer,
    'antwort': antwort?.toJson(),
    'feldWerte': feldWerte,
    'schadensaufstellung': schadensaufstellung?.toJson(),
    'entwurf': entwurf?.toJson(),
    'schreibenNummer': schreibenNummer,
    'dokumentPfad': dokumentPfad,
    'aktenOrdner': aktenOrdner,
    'abgeschlossenAm': abgeschlossenAm?.toIso8601String(),
  };
}
