import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/services/mandant_erkennung.dart';
import 'package:equatable/equatable.dart';

/// Welcher Ausschnitt des Berichts gezeigt wird.
///
/// Erster Eintrag ist die Voreinstellung, und sie ist mit Bedacht nicht „alle":
/// bei viertausend Zeilen ist eine vollständige Liste keine Prüfung, sondern
/// nur der Beweis, dass man nicht geprüft hat. Gezeigt wird deshalb zuerst das,
/// wozu ein Mensch etwas zu sagen hat.
enum ImportSicht {
  zuPruefen('Zu prüfen'),
  neu('Neu'),
  ergaenzt('Ergänzt'),
  unveraendert('Unverändert'),
  alle('Alle');

  final String bezeichnung;

  const ImportSicht(this.bezeichnung);
}

/// Suche und Ausschnitt über den Zeilen eines Importberichts.
class ImportFilter extends Equatable {
  final String query;
  final ImportSicht sicht;

  const ImportFilter({this.query = '', this.sicht = ImportSicht.zuPruefen});

  ImportFilter copyWith({String? query, ImportSicht? sicht}) =>
      ImportFilter(query: query ?? this.query, sicht: sicht ?? this.sicht);

  /// [aehnliche] sind die Ähnlichkeitstreffer je Zeile (`MandantErkennung`):
  /// Zeilen, zu denen es einen ähnlich geschriebenen Mandanten im Register
  /// gibt. Sie zählen zusätzlich zu „zu prüfen" — ohne das versteckte die
  /// Voreinstellung genau die Zeilen, um derentwillen der Hinweis gebaut wird.
  List<ImportEintrag> anwenden(
    List<ImportEintrag> eintraege, {
    Map<int, List<MandantVorschlag>> aehnliche = const {},
  }) => [
    for (final eintrag in eintraege)
      if (passtZurSicht(eintrag, sicht, aehnliche: aehnliche) &&
          _passtZurSuche(eintrag))
        eintrag,
  ];

  /// Die Zahlen an den Umschaltern — über allen Zeilen, nicht über den
  /// gefilterten: sonst zeigte jeder Umschalter nur noch sich selbst.
  Map<ImportSicht, int> zaehlen(
    List<ImportEintrag> eintraege, {
    Map<int, List<MandantVorschlag>> aehnliche = const {},
  }) => {
    for (final sicht in ImportSicht.values)
      sicht: eintraege
          .where((e) => passtZurSicht(e, sicht, aehnliche: aehnliche))
          .length,
  };

  static bool passtZurSicht(
    ImportEintrag eintrag,
    ImportSicht sicht, {
    Map<int, List<MandantVorschlag>> aehnliche = const {},
  }) => switch (sicht) {
    ImportSicht.alle => true,
    // Abgelehnte Zeilen fallen immer hierher: sie sind der Teil, den der
    // Import nicht entscheiden konnte. Dazu die Zeilen mit ähnlichem Namen
    // im Register — die sieht der Erzeuger über Sitzungsgrenzen hinweg nicht,
    // und genau deshalb muss ein Mensch sie sehen.
    ImportSicht.zuPruefen =>
      eintrag.istAuffaellig || (aehnliche[eintrag.zeile]?.isNotEmpty ?? false),
    ImportSicht.neu => eintrag.art == ImportArt.neu,
    ImportSicht.ergaenzt => eintrag.art == ImportArt.ergaenzt,
    ImportSicht.unveraendert => eintrag.art == ImportArt.unveraendert,
  };

  /// Gesucht wird im Namen und in den Ordnernamen — die beiden Angaben, mit
  /// denen der Anwalt eine Zeile wiedererkennt.
  bool _passtZurSuche(ImportEintrag eintrag) {
    final gesucht = query.trim().toLowerCase();
    if (gesucht.isEmpty) return true;
    if (eintrag.anzeigename.toLowerCase().contains(gesucht)) return true;
    return eintrag.aktenOrdnernamen.any(
      (ordner) => ordner.toLowerCase().contains(gesucht),
    );
  }

  @override
  List<Object?> get props => [query, sicht];
}
