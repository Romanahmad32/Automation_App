import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/core/general_classes/kennzeichen_normalisierung.dart';
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
/// **Ausbauweg:** Kandidaten liefern heute die beiden Kennzeichen-Quellen
/// ([FeldDatenquelle.kennzeichenMandant] aus Vorgang + Register,
/// [FeldDatenquelle.kennzeichenGegner] aus Vorgang + Zentralruf-Antwort) —
/// dort stehen mehrere Werte nebeneinander. Die nächsten Anwärter, sobald der
/// Bestand sie mehrfach kennt: [FeldDatenquelle.versichererName]
/// (Wissensbasis + Antwort) und [FeldDatenquelle.mandantName] (Register-Eintrag
/// + Namens-Schnappschuss des Vorgangs). Je Quelle ein `case` in [fuer] — mehr
/// braucht keine der Stellen, die diese Klasse benutzen.
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
      case FeldDatenquelle.kennzeichenGegner:
        // Dieselben zwei Bestände und dieselbe Rangfolge, die
        // `VorgangPrefillMatcher` für dieses Feld nimmt (`vorgang.kennzeichen
        // ?? antwort?.kennzeichen`). Vorbelegt wird der erste; angeboten
        // werden beide, denn sie können auseinanderlaufen: Die Referenz trägt
        // das beim Start getippte Kennzeichen, die Antwort das, unter dem der
        // Zentralruf den Wagen kennt — welches im Anspruchsschreiben stehen
        // soll, entscheidet der Anwalt.
        return _kennzeichen([
          if (vorgang?.kennzeichen != null)
            FeldVorschlag(vorgang!.kennzeichen!, PrefillQuelle.vorgang),
          if (vorgang?.antwort?.kennzeichen != null)
            FeldVorschlag(
              vorgang!.antwort!.kennzeichen!,
              PrefillQuelle.antwort,
            ),
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

  /// Kennzeichen in die Konvention `HG-E 1427` gebracht — soweit die
  /// Aufteilung eindeutig ist —, Leeres verworfen, Doppelte entfernt.
  ///
  /// Ein mehrdeutiger Bestandswert (`HGE1427` — `HG-E 1427` oder `H-GE 1427`?)
  /// wird **nicht geraten**, sondern so angeboten, wie er im Bestand steht:
  /// Die Auswahl zeigt, was da ist, und stellt nicht eine Aufteilung als
  /// Tatsache hin, die niemand entschieden hat.
  ///
  /// Verglichen wird über [gleichesKennzeichen] und nicht über die Zeichen:
  /// Derselbe Wagen steht im Vorgang als `HG-E 1427` und im Register als
  /// `HGE1427`, und zweimal dasselbe Fahrzeug in einer Auswahl sieht nach zwei
  /// Fahrzeugen aus. Der **erste** Treffer gewinnt, deshalb steht der Vorgang
  /// in [fuer] vorn: Er ist der Bestand zu genau diesem Unfall — und der ist
  /// dank Referenz-Konvention auch der eindeutig geschriebene.
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
