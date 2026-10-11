import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:equatable/equatable.dart';

/// Ein Auftrag an `POST /api/Vollmacht/drucken|oeffnen` (§4.11): welche
/// Vorlage, zu welchem Vorgang, mit welchen geprüften Kopfdaten. Die
/// Feldnamen in [toJson] sind die des `VollmachtAuftragDto`.
///
/// Leere Werte gehen leer hinaus — die Schreiblinie dafür setzt der Dienst
/// (#171). Das Tatdatum fehlt mit Absicht: Es steht schon in „wegen".
class VollmachtAuftrag extends Equatable {
  final VollmachtArt art;

  /// Referenz des Vorgangs — bestimmt im Dienst den Arbeitsordner der Datei.
  final String referenz;

  final VollmachtKopfdaten kopfdaten;

  const VollmachtAuftrag({
    required this.art,
    required this.referenz,
    required this.kopfdaten,
  });

  Map<String, dynamic> toJson() => {
    'art': art.wert,
    'referenz': referenz,
    'mandantVorname': kopfdaten.vorname.trim(),
    'mandantNachname': kopfdaten.nachname.trim(),
    'mandantStrasse': kopfdaten.strasse.trim(),
    'mandantPlz': kopfdaten.plz.trim(),
    'mandantOrt': kopfdaten.ort.trim(),
    'mandantTelefon': kopfdaten.telefon.trim(),
    'mandantEmail': kopfdaten.email.trim(),
    'unfalldatum': kopfdaten.unfalldatum.trim(),
    'inSachen': kopfdaten.inSachen.trim(),
    'wegen': kopfdaten.wegen.trim(),
  };

  /// Gleich ist, was gleich beim Dienst ankommt. Das Tatdatum zählt so nur
  /// über „wegen": Ist der Text von Hand geschrieben, ändert ein anderes
  /// Tatdatum am Papier nichts — „In Word öffnen" öffnet dann dieselbe Datei
  /// wieder, statt sie neu auszufüllen (die Word womöglich noch offen hält).
  @override
  List<Object?> get props => [...toJson().values];
}
