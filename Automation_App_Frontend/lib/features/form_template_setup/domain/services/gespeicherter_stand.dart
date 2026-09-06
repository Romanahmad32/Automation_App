import 'package:automation_app/features/form_template_setup/domain/services/vorlagen_stand.dart';
import 'package:equatable/equatable.dart';

/// Der Stand einer Vorlage, wie er **mitgespeichert** wird — das Kurzergebnis
/// von [VorlagenStand] für die Übersichtstabelle (#104 Stufe 4).
///
/// Warum überhaupt gespeichert: [VorlagenStand] braucht die Platzhalter der
/// verknüpften Word-Dateien. Die Übersicht hat sie nicht und dürfte sie sich
/// auch nicht holen — sie müsste beim Öffnen des Tabs für jede Vorlage ein
/// Word-Dokument einlesen lassen. Der Editor kennt sie ohnehin, also schreibt
/// er sein Ergebnis beim Speichern mit, und die Übersicht liest es nur.
/// **Es wird nie nachgerechnet**: Was hier steht, kommt aus genau der einen
/// Rechnung in [VorlagenStand] ([aus]).
///
/// Wo es steht: in der `fields`-Spalte, die das Backend als opakes JSON
/// verlustfrei durchreicht (`FormTemplateDto.Fields`). Damit kommt Stufe 4
/// ohne Änderung am HTTP-Vertrag, an der Datenbank und am Dienst aus.
///
/// Die Form auf der Leitung ist deshalb zweigestaltig, und beide werden
/// gelesen:
///
/// * **nackte Liste** — der Bestand vor #104: `[ {Feld}, {Feld} … ]`. Kein
///   Stand, also [lesen] `null` → die Übersicht sagt „Noch nicht geprüft".
/// * **Objekt** — seit #104: `{"felder": [ … ], "stand": { … }}`.
///
/// Geschrieben wird die zweite Form nur, wenn wirklich ein Stand vorliegt
/// ([verpacke] mit `null` gibt die nackte Liste zurück): Wer den Stand nicht
/// kennt, soll das Format nicht anfassen.
class GespeicherterStand extends Equatable {
  const GespeicherterStand({
    required this.vollstaendig,
    required this.offen,
    required this.warnungen,
  });

  /// Das Kurzergebnis genau einer [VorlagenStand]-Rechnung — die einzige
  /// Stelle, an der ein Stand entsteht.
  factory GespeicherterStand.aus(VorlagenStand stand) => GespeicherterStand(
    vollstaendig: stand.istVollstaendig,
    offen: stand.anzahlOffen,
    warnungen: stand.hatWarnungen,
  );

  /// Der Stand einer Vorlage **ohne jede Word-Datei** — der Fall einer frisch
  /// duplizierten Vorlage.
  ///
  /// Unvollständig, aber ohne Zahl: Ohne Datei kennt niemand die Platzhalter,
  /// es ist also nichts zu zählen. Dieselbe Aussage träfe [aus] auf einen
  /// dateilosen [VorlagenStand] — die Konstante spart der Kopie nur den Weg
  /// über eine Rechnung, deren Eingaben allesamt leer wären.
  static const GespeicherterStand ohneDatei = GespeicherterStand(
    vollstaendig: false,
    offen: 0,
    warnungen: false,
  );

  /// [VorlagenStand.istVollstaendig] — mindestens eine Word-Datei **und** kein
  /// Platzhalter ohne Feld.
  final bool vollstaendig;

  /// [VorlagenStand.anzahlOffen] — Platzhalter ohne Feld **und** Felder ohne
  /// Vorkommen zusammen.
  final int offen;

  /// [VorlagenStand.hatWarnungen] — mindestens ein Feld kommt in keiner Datei
  /// vor. Das hält die Vorlage nicht auf, macht sie also nicht unvollständig.
  final bool warnungen;

  /// Die Fassung des Eintrags. Ein Eintrag mit einer anderen Zahl wird
  /// **nicht** ausgelegt (siehe [lesen]).
  static const int fassung = 1;

  /// Der Schlüssel der Feldliste in der Objektform.
  static const String felderSchluessel = 'felder';

  /// Der Schlüssel des Standeintrags in der Objektform.
  static const String standSchluessel = 'stand';

  Map<String, dynamic> toJson() => {
    'version': fassung,
    'vollstaendig': vollstaendig,
    'offen': offen,
    'warnungen': warnungen,
  };

  /// Der Stand aus dem Inhalt der `fields`-Spalte — `null` heißt **unbekannt**,
  /// nicht „unvollständig".
  ///
  /// `null` kommt in vier Fällen: nackte Liste (Bestand vor #104), Objekt ohne
  /// Standeintrag, Eintrag einer fremden [fassung], kaputter Eintrag. Bei einer
  /// fremden Fassung wird bewusst nichts geraten — „noch nicht geprüft" ist
  /// dann die einzige Aussage, die sicher stimmt.
  static GespeicherterStand? lesen(Object? felderJson) {
    if (felderJson is! Map) return null;
    final roh = felderJson[standSchluessel];
    if (roh is! Map) return null;
    if (roh['version'] != fassung) return null;
    final vollstaendig = roh['vollstaendig'];
    final offen = roh['offen'];
    final warnungen = roh['warnungen'];
    if (vollstaendig is! bool || offen is! int || warnungen is! bool) {
      return null;
    }
    return GespeicherterStand(
      vollstaendig: vollstaendig,
      offen: offen,
      warnungen: warnungen,
    );
  }

  /// Die Feldliste aus dem Inhalt der `fields`-Spalte — aus beiden Formen.
  /// Was sich nicht als Liste lesen lässt, ergibt die leere Liste; eine
  /// Ausnahme hier machte aus einer unlesbaren Vorlage eine unbedienbare Seite.
  static List<dynamic> felderAus(Object? felderJson) {
    if (felderJson is List) return felderJson;
    if (felderJson is Map) {
      final felder = felderJson[felderSchluessel];
      if (felder is List) return felder;
    }
    return const [];
  }

  /// Feldliste und Stand in der Form, die auf die Leitung geht. Ohne [stand]
  /// bleibt es bei der nackten Liste — dann ist das JSON byteidentisch zu dem,
  /// was vor #104 hinausging.
  static Object verpacke(List<dynamic> felder, GespeicherterStand? stand) {
    if (stand == null) return felder;
    return {felderSchluessel: felder, standSchluessel: stand.toJson()};
  }

  @override
  List<Object?> get props => [vollstaendig, offen, warnungen];
}
