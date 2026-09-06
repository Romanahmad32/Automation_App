import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';

/// Welche Feldzeilen der Vorlagenkarte gerade zu sehen sind (#104) — die
/// Auswahl über der Feldertabelle.
///
/// Warum überhaupt gefiltert wird: Eine gewachsene Vorlage hat achtzehn und
/// mehr Felder, von denen an einem Arbeitstag zwei etwas brauchen. Wer sie in
/// der vollen Liste suchen muss, findet sie nicht — die Rechnung aus
/// [VorlagenStand] steht dann zwar über der Karte, aber sie zeigt nicht auf
/// die Zeile, um die es geht.
///
/// **Die Regeln stehen hier und nicht im Widget.** Beide sind schon woanders
/// festgelegt und werden nur wiederverwendet: „offen" ist
/// [VorlagenStand.felderOhneVorkommen], „zu prüfen" ist derselbe mehrdeutige
/// Name, den `FeldNameHinweis` unter dem Feld erklärt
/// ([FeldDatenquelleErkennung]). Eine zweite Regel danebenzustellen hiesse,
/// dass der Filter etwas anderes zählt, als die Zeile darunter anzeigt.
enum FelderFilter {
  alle('Alle'),
  nurOffene('Nur offene'),
  zuPruefen('Zu prüfen');

  const FelderFilter(this.beschriftung);

  /// Aufschrift des Auswahlknopfs, ohne Zahl.
  final String beschriftung;

  /// Aufschrift samt Zahl — „Nur offene (3)". Ohne Zahl bleibt es bei der
  /// blossen Beschriftung; [alle] trägt bewusst keine, sie wäre nur die
  /// Feldzahl, die schon im Kartentitel steht.
  String beschriftungMitZahl(int? zahl) =>
      zahl == null ? beschriftung : '$beschriftung ($zahl)';

  /// Die Indizes aus [fields], die unter diesem Filter sichtbar bleiben — in
  /// der Reihenfolge der Felder.
  ///
  /// [feldname] löst den Control-Schlüssel (`field_0`, …) zum echten Namen
  /// auf; solange die Detailseite offen ist, steht in `FieldData.label` nur
  /// der Schlüssel (siehe `FALLSTRICKE.md`). Ohne [stand] gibt es nichts zu
  /// filtern: Dann ist über die Vorlage noch nichts gerechnet, und die Karte
  /// zeigt alles, statt willkürlich Zeilen wegzulassen.
  List<int> sichtbareIndizes({
    required List<FieldData> fields,
    required String? Function(String controlKey) feldname,
    required VorlagenStand? stand,
  }) {
    final alleIndizes = [for (var i = 0; i < fields.length; i++) i];
    if (this == FelderFilter.alle || stand == null) return alleIndizes;

    if (this == FelderFilter.nurOffene) {
      final offen = {
        for (final name in stand.felderOhneVorkommen) name.trim().toLowerCase(),
      };
      return [
        for (final i in alleIndizes)
          if (offen.contains(
            (feldname(fields[i].label) ?? '').trim().toLowerCase(),
          ))
            i,
      ];
    }

    return [
      for (final i in alleIndizes)
        if (istZuPruefen(
          feldname(fields[i].label),
          datenquelleGesetzt: fields[i].datenquelle.istGesetzt,
        ))
          i,
    ];
  }

  /// Die Zahl auf dem Auswahlknopf; null heißt „ohne Zahl" ([alle]).
  ///
  /// Für [nurOffene] ist das **nicht** die Zahl der Zeilen: Ein Platzhalter
  /// ohne Feld ist genauso offen, hat aber keine Zeile, in der er stehen
  /// könnte ([VorlagenStand.anzahlOffen] zählt beide Richtungen). Stünde hier
  /// nur die Zeilenzahl, sagte der Knopf „Nur offene (0)", während über der
  /// Karte drei fehlende Platzhalter gemeldet sind.
  int? anzahl({
    required List<FieldData> fields,
    required String? Function(String controlKey) feldname,
    required VorlagenStand? stand,
  }) => switch (this) {
    FelderFilter.alle => null,
    FelderFilter.nurOffene => stand?.anzahlOffen ?? 0,
    FelderFilter.zuPruefen => sichtbareIndizes(
      fields: fields,
      feldname: feldname,
      stand: stand,
    ).length,
  };

  /// Womit die Karte aufgeht: [alle], solange die Vorlage vollständig ist,
  /// sonst [nurOffene].
  ///
  /// Der Anwalt öffnet eine unvollständige Vorlage, weil ihr etwas fehlt —
  /// dann soll das Fehlende dastehen und nicht in achtzehn Zeilen versteckt
  /// sein. Ist sie vollständig, wäre eine leere gefilterte Liste beim
  /// Aufgehen dagegen nur verwirrend.
  static FelderFilter start(VorlagenStand? stand) =>
      stand == null || stand.istVollstaendig ? alle : nurOffene;

  /// Ob ein Feld „zu prüfen" ist: Sein Name meint zwei einzeln gespeicherte
  /// Angaben zugleich (`{{VersicherungPlzOrt}}`) und bleibt deshalb ungebunden
  /// — genau der Fall, den `FeldNameHinweis` unter dem Feld erklärt.
  ///
  /// [datenquelleGesetzt] beendet die Frage: Dann hat der Anwalt entschieden,
  /// die Quelle gewinnt über die Erkennung, und der Hinweis schweigt. Ohne
  /// diese Bedingung führte der Filter Zeilen auf, an denen nichts zu sehen
  /// ist.
  static bool istZuPruefen(String? name, {required bool datenquelleGesetzt}) =>
      !datenquelleGesetzt &&
      FeldDatenquelleErkennung.erkenne(name ?? '').hinweis != null;
}
