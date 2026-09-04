import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:equatable/equatable.dart';

/// Um wie viel ein Datumsfeld beim Ausfüllen in die Zukunft vorbelegt wird —
/// je Feld einstellbar (§5.3).
///
/// Vorher steckte diese Regel als Sonderfall im Ausfüllschritt: Ein Feldname
/// mit „zahlungsfrist" bekam heute + 35 Tage, jedes andere Datumsfeld heute.
/// Wer eine andere Frist brauchte, hatte keinen Weg dorthin außer dem
/// Quellcode. Jetzt gehört die Angabe zum Feld und steht im Vorlageneditor.
///
/// **Kalenderrechnung, kein [Duration].** `DateTime.add` rechnet in fester
/// Zeitspanne — ein „Jahr" wären dort 365 Tage und eine Sommerzeitumstellung
/// verschöbe das Ergebnis um eine Stunde (und damit über Mitternacht um einen
/// Tag). Gerechnet wird deshalb über den [DateTime]-Konstruktor, der
/// Feldüberläufe normalisiert. Fachlich richtig ist genau das: „in einem
/// Monat" meint denselben Tag im nächsten Monat, nicht 30 Tage.
///
/// Die Überläufe, die daraus folgen, sind gewollt und sichtbar:
///
/// * 29.02.2028 + 1 Jahr → **01.03.2029** (2029 hat keinen 29. Februar)
/// * 31.01.2027 + 1 Monat → **03.03.2027** (Februar 2027 hat 28 Tage)
/// * 31.01.2028 + 1 Monat → **02.03.2028** (Februar 2028 hat 29 Tage)
///
/// **Abgrenzung zu §8:** Das ist keine Fristenlogik. Es gibt keine
/// Werktagsverschiebung, keine Feiertage, keine Wiedervorlage und keine
/// Erinnerung — 4 Wochen sind hier 28 Kalendertage. Der Wert landet als
/// *Vorschlag* im sichtbaren Datumsfeld des Ausfüllschritts und ist dort
/// überschreibbar; die fachliche Verantwortung für die Frist bleibt beim
/// Anwalt. Eine App, die Fristen selbst berechnet, müsste sie auch überwachen
/// — und genau das schließt §8 aus.
class DatumsVorbelegung extends Equatable {
  final int jahre;
  final int monate;
  final int wochen;
  final int tage;

  const DatumsVorbelegung({
    this.jahre = 0,
    this.monate = 0,
    this.wochen = 0,
    this.tage = 0,
  });

  /// [basis] um diese Vorbelegung verschoben. Überläufe normalisiert der
  /// [DateTime]-Konstruktor (siehe Klassenkommentar).
  DateTime anwendenAuf(DateTime basis) => DateTime(
    basis.year + jahre,
    basis.month + monate,
    basis.day + wochen * 7 + tage,
  );

  /// Keine Verschiebung — das Feld wird mit dem heutigen Datum vorbelegt.
  bool get istHeute => jahre == 0 && monate == 0 && wochen == 0 && tage == 0;

  /// Lesbare Kurzform für Hinweise: „heute", „heute + 5 Wochen",
  /// „heute + 1 Jahr, 2 Wochen und 9 Tage".
  String get beschreibung {
    if (istHeute) return 'heute';
    final teile = <String>[
      if (jahre != 0) _menge(jahre, 'Jahr', 'Jahre'),
      if (monate != 0) _menge(monate, 'Monat', 'Monate'),
      if (wochen != 0) _menge(wochen, 'Woche', 'Wochen'),
      if (tage != 0) _menge(tage, 'Tag', 'Tage'),
    ];
    if (teile.length == 1) return 'heute + ${teile.single}';
    final letztes = teile.removeLast();
    return 'heute + ${teile.join(', ')} und $letztes';
  }

  factory DatumsVorbelegung.fromJson(Map<String, dynamic> json) =>
      DatumsVorbelegung(
        jahre: _ganzzahl(json['jahre']),
        monate: _ganzzahl(json['monate']),
        wochen: _ganzzahl(json['wochen']),
        tage: _ganzzahl(json['tage']),
      );

  Map<String, dynamic> toJson() => {
    'jahre': jahre,
    'monate': monate,
    'wochen': wochen,
    'tage': tage,
  };

  /// Die alte Namensregel als **Rückfall** für Felder, an denen nie eine
  /// Vorbelegung eingestellt wurde: „Zahlungsfrist" → 5 Wochen, jedes andere
  /// „Frist"-Feld → 4 Wochen, sonst heute.
  ///
  /// Beide Werte stehen so seit der Entscheidung vom 29.08.2026: „Frist" und
  /// „Zahlungsfrist" sind verschiedene Felder mit verschiedenen Fristen.
  ///
  /// **Die Reihenfolge der beiden Prüfungen ist die Regel** — „frist" steckt
  /// in „zahlungsfrist". Wer sie tauscht, gibt jedem Zahlungsfrist-Feld
  /// stillschweigend 4 statt 5 Wochen; auffallen würde das erst am falschen
  /// Datum im nächsten Schreiben.
  ///
  /// Verglichen wird über [FeldDatenquelleErkennung.normalisiere] statt über
  /// ein blosses `toLowerCase()`: sonst bekäme `{{Zahlungs-Frist}}` die
  /// Vorbelegung nicht, obwohl dasselbe gemeint ist.
  ///
  /// Die 4 Wochen sind 28 Kalendertage ohne Werktagsverschiebung — kein
  /// Versehen, sondern §8: Die App führt keine Fristenlogik. Der Wert ist ein
  /// sichtbarer Vorschlag im Datumsfeld und dort überschreibbar.
  static DatumsVorbelegung ausFeldname(String label) {
    final name = FeldDatenquelleErkennung.normalisiere(label);
    if (name.contains('zahlungsfrist')) {
      return const DatumsVorbelegung(wochen: 5);
    }
    if (name.contains('frist')) return const DatumsVorbelegung(wochen: 4);
    return const DatumsVorbelegung();
  }

  /// Fehlende oder unbrauchbare Schlüssel gelten als 0: Eine Vorlage, die nur
  /// `wochen` gespeichert hat, soll laden statt zu werfen.
  static int _ganzzahl(Object? wert) => wert is int ? wert : 0;

  static String _menge(int wert, String einzahl, String mehrzahl) =>
      '$wert ${wert == 1 ? einzahl : mehrzahl}';

  @override
  List<Object?> get props => [jahre, monate, wochen, tage];
}
