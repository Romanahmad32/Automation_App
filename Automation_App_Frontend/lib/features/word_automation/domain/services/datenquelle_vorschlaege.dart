import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/kennzeichen_normalisierung.dart';
import 'package:equatable/equatable.dart';

/// Ein zur Wahl stehender Wert für ein Formularfeld samt seiner Herkunft.
///
/// Das Gegenstück zu `PrefillWert`: Der trägt den *einen* Wert, mit dem ein
/// Feld vorbelegt wird; dieser trägt einen von mehreren, unter denen der Anwalt
/// wählt. Die [herkunft] ist dieselbe Aufzählung, damit „aus dem
/// Mandantenregister" am Feld und im Auswahldialog denselben Wortlaut hat.
class FeldVorschlag extends Equatable {
  final String wert;
  final PrefillQuelle herkunft;

  const FeldVorschlag(this.wert, this.herkunft);

  @override
  List<Object?> get props => [wert, herkunft];
}

/// Sammelt je [FeldDatenquelle] **alle** bekannten Werte, statt sich für einen
/// zu entscheiden — die Auswahlhilfe am Feld im Ausfüllschritt (#17).
///
/// Die Arbeitsteilung mit `VorgangPrefillMatcher` ist der Punkt: Der belegt vor,
/// wenn die Antwort eindeutig ist, und lässt das Feld sonst leer (§1.3). Was
/// dabei liegen bleibt — die drei Fahrzeuge eines Mandanten, von denen das
/// Register nicht weiß, welches im Unfall stand — bietet diese Klasse zur Wahl
/// an. Beide lesen dieselbe Datenquelle, damit „vorbelegt" und „zur Wahl" nicht
/// aus verschiedenen Beständen kommen.
///
/// **Ausbauweg:** Heute liefert nur [FeldDatenquelle.kennzeichenMandant]
/// Kandidaten, weil nur dort mehrere Werte nebeneinander stehen. Die nächsten
/// Anwärter, sobald der Bestand sie mehrfach kennt:
/// [FeldDatenquelle.kennzeichenGegner] (Vorgang und Zentralruf-Antwort können
/// abweichen), [FeldDatenquelle.versichererName] (Wissensbasis + Antwort) und
/// [FeldDatenquelle.mandantName] (Register-Eintrag + Namens-Schnappschuss des
/// Vorgangs). Je Quelle ein `case` in [fuer] — mehr braucht keine der Stellen,
/// die diese Klasse benutzen.
class DatenquelleVorschlaege {
  const DatenquelleVorschlaege._();

  /// Die zur Wahl stehenden Werte einer Quelle, in der Reihenfolge „naheliegend
  /// zuerst": der Vorgang vor dem Register. Leere Liste heißt: keine
  /// Auswahlhilfe an diesem Feld.
  static List<FeldVorschlag> fuer(
    FeldDatenquelle quelle, {
    Vorgang? vorgang,
    Mandant? mandant,
  }) {
    switch (quelle) {
      case FeldDatenquelle.kennzeichenMandant:
        return _kennzeichen([
          if (vorgang?.geschaedigtenKennzeichen != null)
            FeldVorschlag(
              vorgang!.geschaedigtenKennzeichen!,
              PrefillQuelle.vorgang,
            ),
          for (final wert in mandant?.kennzeichen ?? const <String>[])
            FeldVorschlag(wert, PrefillQuelle.mandant),
        ]);
      default:
        return const [];
    }
  }

  /// Die Vorschläge je Feldname einer Vorlage — nur für Felder, die welche
  /// haben.
  ///
  /// Die effektive Quelle wird genauso bestimmt wie in `VorgangPrefillMatcher`:
  /// Ist am Feld eine gewählt, gilt sie; sonst löst [FeldDatenquelleErkennung]
  /// den Namen auf. Liefe das hier nach eigener Regel, hätte ein Feld
  /// Vorschläge aus einem anderen Bestand als seine Vorbelegung.
  static Map<String, List<FeldVorschlag>> fuerFelder(
    List<FieldData> fields, {
    Vorgang? vorgang,
    Mandant? mandant,
  }) {
    final ergebnis = <String, List<FeldVorschlag>>{};
    for (final field in fields) {
      final quelle = field.datenquelle.istGesetzt
          ? field.datenquelle
          : FeldDatenquelleErkennung.quelleFuer(field.label);
      final vorschlaege = fuer(quelle, vorgang: vorgang, mandant: mandant);
      if (vorschlaege.isNotEmpty) ergebnis[field.label] = vorschlaege;
    }
    return ergebnis;
  }

  /// Kennzeichen in die Konvention `HG-E 1427` gebracht, Leeres verworfen,
  /// Doppelte entfernt.
  ///
  /// Verglichen wird über [gleichesKennzeichen] und nicht über die Zeichen:
  /// Derselbe Wagen steht im Vorgang als `HG-E 1427` und im Register als
  /// `HGE1427`, und zweimal dasselbe Fahrzeug in einer Auswahl sieht nach zwei
  /// Fahrzeugen aus. Der **erste** Treffer gewinnt, deshalb steht der Vorgang
  /// in [fuer] vorn: Er ist der Bestand zu genau diesem Unfall.
  static List<FeldVorschlag> _kennzeichen(List<FeldVorschlag> rohe) {
    final ergebnis = <FeldVorschlag>[];
    for (final vorschlag in rohe) {
      final wert = normalizeKennzeichen(vorschlag.wert)?.trim() ?? '';
      if (wert.isEmpty) continue;
      final schonDa = ergebnis.any(
        (vorhanden) => gleichesKennzeichen(vorhanden.wert, wert),
      );
      if (schonDa) continue;
      ergebnis.add(FeldVorschlag(wert, vorschlag.herkunft));
    }
    return ergebnis;
  }
}
