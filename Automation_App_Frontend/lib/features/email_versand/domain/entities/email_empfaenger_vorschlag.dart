import 'package:automation_app/features/email_versand/domain/entities/empfaenger_art.dart';
import 'package:equatable/equatable.dart';

/// Eine Adresse, die die App zum Vorgang schon kennt — anklickbar statt
/// abzutippen (§4.7). Die [herkunft] steht bewusst dabei: Eine Adresse aus
/// einer Zentralruf-Antwort ist etwas anderes als eine aus dem
/// Versicherer-Register, und der Anwalt soll sehen, worauf er sich verlässt.
class EmailEmpfaengerVorschlag extends Equatable {
  final String adresse;

  /// Wem die Adresse gehört, z. B. „Mandant Müller" oder „HUK-COBURG".
  final String bezeichnung;

  final EmpfaengerArt art;

  /// Woher die App die Adresse hat, z. B. „aus der Zentralruf-Antwort".
  final String herkunft;

  const EmailEmpfaengerVorschlag({
    required this.adresse,
    required this.bezeichnung,
    required this.art,
    required this.herkunft,
  });

  @override
  List<Object?> get props => [adresse, bezeichnung, art, herkunft];
}
