import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:equatable/equatable.dart';

/// Ein Auftrag an `POST /api/Vollmacht/drucken|oeffnen` (§4.11): welche
/// Vorlage, zu welchem Vorgang, mit welchen geprüften Kopfdaten. Die
/// Feldnamen in [toJson] sind die des `VollmachtAuftragDto`.
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

  @override
  List<Object?> get props => [art, referenz, kopfdaten];
}
