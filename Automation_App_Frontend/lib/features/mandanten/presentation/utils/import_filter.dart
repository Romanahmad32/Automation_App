import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
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

  List<ImportEintrag> anwenden(List<ImportEintrag> eintraege) => [
    for (final eintrag in eintraege)
      if (passtZurSicht(eintrag, sicht) && _passtZurSuche(eintrag)) eintrag,
  ];

  /// Die Zahlen an den Umschaltern — über allen Zeilen, nicht über den
  /// gefilterten: sonst zeigte jeder Umschalter nur noch sich selbst.
  Map<ImportSicht, int> zaehlen(List<ImportEintrag> eintraege) => {
    for (final sicht in ImportSicht.values)
      sicht: eintraege.where((e) => passtZurSicht(e, sicht)).length,
  };

  static bool passtZurSicht(ImportEintrag eintrag, ImportSicht sicht) =>
      switch (sicht) {
        ImportSicht.alle => true,
        // Abgelehnte Zeilen fallen immer hierher: sie sind der Teil, den der
        // Import nicht entscheiden konnte.
        ImportSicht.zuPruefen => eintrag.istAuffaellig,
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
