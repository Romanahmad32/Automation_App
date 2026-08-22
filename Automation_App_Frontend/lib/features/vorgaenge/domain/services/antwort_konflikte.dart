import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:equatable/equatable.dart';

/// Vorgangsfelder, bei denen eine Zentralruf-Antwort einem bereits erfassten
/// Wert widersprechen kann. Bewusst nur die frei erfassten Felder: das
/// Gegner-Kennzeichen ist Teil der Referenz (fachlicher Schlüssel) und wird
/// nicht per Auswahl überschrieben — eine Kennzeichen-Abweichung meldet
/// bereits der Antwort-Parser als Warnung (ZentralrufReplyWarnings).
enum AntwortKonfliktFeld {
  gegner('Gegner / Versicherer'),
  unfallDatum('Unfalldatum');

  final String displayName;

  const AntwortKonfliktFeld(this.displayName);
}

/// Eine einzelne Abweichung zwischen dem am Vorgang erfassten Wert und dem
/// Wert aus der Zentralruf-Antwort.
class AntwortKonflikt extends Equatable {
  final AntwortKonfliktFeld feld;
  final String erfassterWert;
  final String antwortWert;

  const AntwortKonflikt({
    required this.feld,
    required this.erfassterWert,
    required this.antwortWert,
  });

  @override
  List<Object?> get props => [feld, erfassterWert, antwortWert];
}

/// Findet Abweichungen zwischen Vorgang und Zentralruf-Antwort und wendet die
/// Entscheidung des Anwalts beim Merge an — statt Antwortwerte still zu
/// verwerfen, sobald das Vorgangsfeld schon belegt ist (Punkt 6 des
/// Verbesserungsplans).
class AntwortKonflikte {
  const AntwortKonflikte._();

  /// Abweichungen, die eine Übernahme von [data] in [vorgang] still verlieren
  /// würde: beide Seiten haben einen Wert und er unterscheidet sich (tolerant
  /// gegenüber Groß-/Kleinschreibung und Rand-Leerzeichen).
  static List<AntwortKonflikt> finde(
    Vorgang vorgang,
    ZentralrufReplyData data,
  ) {
    final konflikte = <AntwortKonflikt>[];

    void pruefe(AntwortKonfliktFeld feld, String? erfasst, String? antwort) {
      final links = (erfasst ?? '').trim();
      final rechts = (antwort ?? '').trim();
      if (links.isEmpty || rechts.isEmpty) return;
      if (links.toUpperCase() == rechts.toUpperCase()) return;
      konflikte.add(
        AntwortKonflikt(feld: feld, erfassterWert: links, antwortWert: rechts),
      );
    }

    pruefe(AntwortKonfliktFeld.gegner, vorgang.gegner, data.versichererName);
    pruefe(
      AntwortKonfliktFeld.unfallDatum,
      vorgang.unfallDatum,
      data.unfallDatum,
    );
    return konflikte;
  }

  /// Übernimmt [data] in [vorgang] (wie [Vorgang.mitAntwort]) und setzt für
  /// die in [antwortGewinnt] gewählten Felder den Antwortwert durch — für alle
  /// übrigen Konfliktfelder bleibt der erfasste Wert stehen (bisheriges
  /// Verhalten).
  static Vorgang uebernehmen(
    Vorgang vorgang,
    ZentralrufReplyData data, {
    Set<AntwortKonfliktFeld> antwortGewinnt = const {},
  }) {
    var ergebnis = vorgang.mitAntwort(data);
    for (final feld in antwortGewinnt) {
      switch (feld) {
        case AntwortKonfliktFeld.gegner:
          final wert = data.versichererName?.trim();
          if (wert != null && wert.isNotEmpty) {
            ergebnis = ergebnis.copyWith(gegner: wert);
          }
        case AntwortKonfliktFeld.unfallDatum:
          final wert = data.unfallDatum?.trim();
          if (wert != null && wert.isNotEmpty) {
            ergebnis = ergebnis.copyWith(unfallDatum: wert);
          }
      }
    }
    return ergebnis;
  }
}
