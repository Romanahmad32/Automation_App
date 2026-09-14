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
  ///
  /// Der Einschub sagt bewusst nicht „… zu diesem Vorgang": Er steht in der
  /// Hinweiszeile **unter dem Feld**, und die ist schmal — der Zusatz ist dort
  /// der Unterschied zwischen zwei Zeilen und abgeschnittenem Text, obwohl er
  /// nichts erklärt (man steht ja in diesem Vorgang). Die Sammelzeile über dem
  /// Formular (`VorgangsdatenHinweis`) hat Platz und nennt ihn weiterhin.
  ///
  /// Es gibt bewusst **keine** Quelle „aus Ihrem angefangenen Stand" (#133):
  /// Jede Quelle hier ist ein Datenbestand, dem der Anwalt vertraut oder eben
  /// nicht. Sein eigener Tippstand ist keiner — wo er den vorbelegten Wert
  /// überschrieben hat, nennt das Formular gar keine Herkunft mehr, statt eine
  /// zu behaupten, die zum angezeigten Wert nicht mehr passt.
  gespeichert('aus dem letzten Schreiben');

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
