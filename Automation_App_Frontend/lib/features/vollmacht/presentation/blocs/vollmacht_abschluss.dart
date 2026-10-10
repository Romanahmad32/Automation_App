import 'package:equatable/equatable.dart';

/// Auf welchem Weg die Vollmacht zum Abschluss kam.
enum VollmachtAbschlussWeg {
  /// Die App hat gedruckt; Word hat den Auftrag angenommen.
  gedruckt,

  /// Der Anwalt hat in Word gedruckt und den Druck bestätigt.
  inWord,
}

/// Was nach dem Druck im Dialog stehen bleibt (§4.11, #164): wann, wohin und
/// ob der Vermerk am Vorgang sitzt. Die App weiß nur, dass Word den Auftrag
/// angenommen hat — nicht, ob ein Blatt herauskam. Deshalb schließt sich der
/// Dialog nicht von selbst, sondern lässt den Anwalt nachsteuern.
class VollmachtAbschluss extends Equatable {
  final VollmachtAbschlussWeg weg;
  final DateTime zeitpunkt;

  /// Der Drucker, an den Word übergeben hat; null, wenn unbekannt oder bei
  /// [VollmachtAbschlussWeg.inWord].
  final String? drucker;

  /// Ob der Vermerk „gedruckt" am Vorgang gespeichert ist.
  final bool vermerkt;

  /// Platzhalter, die in der Vorlage stehen geblieben sind (§4.4).
  final List<String> warnungen;

  const VollmachtAbschluss({
    required this.weg,
    required this.zeitpunkt,
    this.drucker,
    required this.vermerkt,
    this.warnungen = const [],
  });

  VollmachtAbschluss mitVermerk(bool vermerkt) => VollmachtAbschluss(
    weg: weg,
    zeitpunkt: zeitpunkt,
    drucker: drucker,
    vermerkt: vermerkt,
    warnungen: warnungen,
  );

  @override
  List<Object?> get props => [weg, zeitpunkt, drucker, vermerkt, warnungen];
}
