import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';

/// Prüft, welche für das Anspruchsschreiben typischerweise benötigten Daten am
/// Vorgang noch fehlen — damit der Anwalt Lücken schon in der
/// Vorgangsübersicht sieht und nachpflegen kann, bevor er im Word-Assistenten
/// steht (Punkt 7 des Verbesserungsplans).
class VorgangVollstaendigkeit {
  const VorgangVollstaendigkeit._();

  /// Menschlich lesbare Namen der fehlenden Daten, leer wenn nichts fehlt.
  /// Abgeschlossene (versendete) Vorgänge melden nie etwas — dort ist nichts
  /// mehr nachzupflegen.
  ///
  /// Die noch ausstehende Zentralruf-Antwort selbst zählt bewusst nicht als
  /// Lücke: Im Status „Angefragt" ist Warten der Normalfall (dafür gibt es
  /// den Warte-Hinweis); gemeldet wird nur, was der Anwalt selbst erfassen
  /// bzw. korrigieren kann.
  static List<String> fehlendeDatenFuerSchreiben(Vorgang vorgang) {
    if (vorgang.status == VorgangStatus.versendet) return const [];

    bool leer(String? wert) => wert == null || wert.trim().isEmpty;

    final fehlt = <String>[];
    if (vorgang.mandantId == null && leer(vorgang.mandantName)) {
      fehlt.add('Mandant');
    }

    // Die Unfall-/Versichererangaben braucht nur das Verkehrsunfall-Schreiben.
    if (vorgang.rechtsgebiet != Rechtsgebiet.verkehrsrecht) return fehlt;

    if (leer(vorgang.unfallDatum) && leer(vorgang.antwort?.unfallDatum)) {
      fehlt.add('Unfalldatum');
    }
    if (leer(vorgang.unfallort)) fehlt.add('Unfallort');
    if (leer(vorgang.geschaedigtenKennzeichen)) {
      fehlt.add('Kennzeichen des Mandanten');
    }

    final antwort = vorgang.antwort;
    if (antwort != null) {
      if (antwort.keinVersichererErmittelt || leer(antwort.versichererName)) {
        fehlt.add('Gegnerischer Versicherer');
      } else if (leer(antwort.versichererStrasse) ||
          leer(antwort.versichererPlz) ||
          leer(antwort.versichererOrt)) {
        fehlt.add('Anschrift des Versicherers');
      }
    }
    return fehlt;
  }
}
