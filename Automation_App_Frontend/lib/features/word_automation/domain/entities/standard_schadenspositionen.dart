/// Eine Standardposition der Schadensaufstellung: Bezeichnung und optional ein
/// vorbelegter Betrag. Mit diesen Zeilen startet eine neu begonnene
/// Aufstellung (§4.4); ohne Betrag bleibt das Betragsfeld leer, und die
/// Position fällt beim Übernehmen von selbst heraus.
class StandardSchadensposition {
  final String bezeichnung;

  /// Vorbelegter Betrag in Euro; `null` heißt: Feld bleibt leer.
  final double? betrag;

  const StandardSchadensposition({required this.bezeichnung, this.betrag});

  factory StandardSchadensposition.fromJson(Map<String, dynamic> json) =>
      StandardSchadensposition(
        bezeichnung: json['bezeichnung'] as String,
        betrag: (json['betrag'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'bezeichnung': bezeichnung,
    'betrag': betrag,
  };

  @override
  bool operator ==(Object other) =>
      other is StandardSchadensposition &&
      other.bezeichnung == bezeichnung &&
      other.betrag == betrag;

  @override
  int get hashCode => Object.hash(bezeichnung, betrag);
}

/// Die fünf Positionen, mit denen eine Schadensaufstellung bei einem
/// Verkehrsunfall-Mandat ab Werk anfängt (§4.4).
///
/// Sie stehen hier und nicht im Formular, weil sie eine fachliche Festlegung
/// sind und keine Eigenheit der Eingabemaske: Das Formular zeigt sie beim
/// Anlegen an, dasselbe „+"-Menü holt eine gelöschte davon zurück, und ein Test
/// hält den Wortlaut gegen die Anforderung. Läge die Liste im Widget, hätte die
/// zweite Verwendung sie abgeschrieben.
///
/// **Reihenfolge und Wortlaut sind der Wortlaut der Anforderung.** Wer hier
/// etwas ändert, ändert zuerst `REQUIREMENTS.md` §4.4 — nicht umgekehrt. Das
/// Backend hält dieselbe Vorgabe in `StandardSchadenspositionenVorgabe`.
///
/// Die Vorgabe ist nur der Rückfall: In den Einstellungen (Reiter
/// „Schadensaufstellung") kann der Anwalt Bezeichnungen **und** Beträge selbst
/// festlegen — geladen über `StandardpositionenCubit`, gespeichert im Backend.
abstract final class StandardSchadenspositionen {
  static const List<StandardSchadensposition> vorgabe = [
    StandardSchadensposition(
      bezeichnung: 'Reparaturkosten netto nach Gutachten',
    ),
    StandardSchadensposition(bezeichnung: 'Wertminderung nach Gutachten'),
    StandardSchadensposition(bezeichnung: 'Unkostenpauschale'),
    StandardSchadensposition(bezeichnung: 'Abschleppkosten / Standgeldkosten'),
    StandardSchadensposition(bezeichnung: 'Sachverständigenkosten'),
  ];

  static List<String> get bezeichnungen => [
    for (final position in vorgabe) position.bezeichnung,
  ];
}
