import 'package:equatable/equatable.dart';

/// Woher ein vorbelegter Formularwert stammt — für die Herkunftsanzeige am
/// Feld im Word-Assistenten. Der Anwalt sieht so je Feld, welchem Datenbestand
/// er gerade vertraut (statt nur einem Sammel-Hinweis „n Felder vorbelegt").
enum PrefillQuelle {
  /// Stammdaten aus dem Mandantenregister.
  mandant('aus dem Mandantenregister'),

  /// Übernommene Zentralruf-Antwort des Vorgangs.
  antwort('aus der Zentralruf-Antwort'),

  /// Beim Starten/Bearbeiten des Vorgangs erfasste Daten (Unfall, Referenz,
  /// Rechtsgebiet, Namens-Schnappschuss).
  vorgang('aus den Vorgangsdaten'),

  /// Beim letzten Schreiben zu diesem Vorgang bestätigte Werte
  /// ([Vorgang.feldWerte], Rückfluss).
  gespeichert('aus dem letzten Schreiben zu diesem Vorgang');

  /// Kleingeschriebener Einschub für Hinweistexte („Vorbelegt aus …").
  final String beschreibung;

  const PrefillQuelle(this.beschreibung);
}

/// Ein vorzubelegender Formularwert samt seiner Herkunft.
class PrefillWert extends Equatable {
  final String wert;
  final PrefillQuelle quelle;

  const PrefillWert(this.wert, this.quelle);

  @override
  List<Object?> get props => [wert, quelle];
}
