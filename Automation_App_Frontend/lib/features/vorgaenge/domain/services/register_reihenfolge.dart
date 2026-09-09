import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';

/// In welcher Richtung die Registeransicht gelesen wird (§6.2).
///
/// Das Registerbuch der Kanzlei läuft chronologisch vorwärts, und so schreibt
/// der Dienst auch die Word-/PDF-Fassung: Jahrgang aufsteigend, darin die
/// laufende Nummer. Am Bildschirm ist das die falsche Richtung — angesehen
/// werden fast immer die jüngsten Zeilen, und die stünden nach tausenden
/// übernommenen Zeilen ganz unten.
///
/// Deshalb **liest die Ansicht dieselbe Folge rückwärts**, statt eine zweite
/// Sortierregel aufzustellen: Wer an der Reihenfolge etwas ändert, ändert
/// weiterhin `RegisterZeilenBau.Aus` im Backend — hier wird sie nur gespiegelt.
/// Ein laufender Vorgang ohne laufende Nummer steht im Bestand hinten am
/// Jahrgang und rückt damit von selbst nach oben, wo er hingehört.
enum RegisterReihenfolge {
  neuesteZuerst('Neueste zuerst'),
  aeltesteZuerst('Älteste zuerst');

  const RegisterReihenfolge(this.bezeichnung);

  /// Wortlaut für die Auswahl in der Filterleiste.
  final String bezeichnung;

  /// Die Vorgabe beim Öffnen der Seite.
  static const RegisterReihenfolge vorgabe = neuesteZuerst;

  List<RegisterZeile> anwenden(List<RegisterZeile> zeilen) => switch (this) {
    neuesteZuerst => zeilen.reversed.toList(),
    aeltesteZuerst => zeilen,
  };
}
