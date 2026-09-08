import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_zeile.dart';
import 'package:equatable/equatable.dart';

/// Die Felder, die der Anwalt an einer historischen Registerzeile ändern darf
/// (§6.2) — der Rumpf von `PUT /api/RegisterHistorie/{id}`.
///
/// Bewusst **nicht** Jahr und laufende Nummer: Die beiden sind der natürliche
/// Schlüssel des Registers. Wären sie änderbar, könnte eine Berichtigung eine
/// zweite Zeile überschreiben oder eine Lücke aufreißen, die vorher keine war.
///
/// Leer ist ein gültiger Wert: Ein Feld zu *leeren* ist eine gewollte
/// Änderung — im gewachsenen Bestand steht manches, was gar nicht in die
/// Spalte gehört.
class RegisterHistorieAenderung extends Equatable {
  final String abteilung;
  final String sachart;
  final String mandant;
  final String gegner;
  final String sachbestand;
  final String unfalldatum;
  final String rechtsgebiet;

  const RegisterHistorieAenderung({
    this.abteilung = '',
    this.sachart = '',
    this.mandant = '',
    this.gegner = '',
    this.sachbestand = '',
    this.unfalldatum = '',
    this.rechtsgebiet = '',
  });

  /// Der Rohstand einer gespeicherten Zeile als Vorbelegung des Dialogs.
  ///
  /// Genau die sieben änderbaren Felder, unverändert übernommen: Ein Dialog,
  /// der mit leeren Feldern aufginge, machte aus „Übernehmen" einen
  /// Löschbefehl.
  factory RegisterHistorieAenderung.aus(RegisterHistorieZeile zeile) =>
      RegisterHistorieAenderung(
        abteilung: zeile.abteilung,
        sachart: zeile.sachart,
        mandant: zeile.mandant,
        gegner: zeile.gegner,
        sachbestand: zeile.sachbestand,
        unfalldatum: zeile.unfalldatum,
        rechtsgebiet: zeile.rechtsgebiet,
      );

  Map<String, dynamic> toJson() => {
    'abteilung': abteilung,
    'sachart': sachart,
    'mandant': mandant,
    'gegner': gegner,
    'sachbestand': sachbestand,
    'unfalldatum': unfalldatum,
    'rechtsgebiet': rechtsgebiet,
  };

  @override
  List<Object?> get props => [
    abteilung,
    sachart,
    mandant,
    gegner,
    sachbestand,
    unfalldatum,
    rechtsgebiet,
  ];
}
