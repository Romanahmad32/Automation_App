import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:equatable/equatable.dart';

/// Eingabedaten zum Anlegen eines neuen Mandanten. Die `id` und `erstelltAm`
/// vergibt das Register beim Speichern (analog zu CreateFormTemplateRequest).
class CreateMandantRequest extends Equatable {
  final Anrede anrede;
  final String vorname;
  final String nachname;
  final String strasseHausnummer;
  final String postleitzahl;
  final String ort;
  final String emailAdresse;
  final String telefonnummer;
  final String notiz;

  /// Persönlicher Zusatzgruß für Mails an diesen Mandanten (§5.1); leer heißt
  /// kein Zusatzgruß.
  final String persoenlicheGrussformel;

  /// Optional: ein bereits vorhandener Akten-Ordner, der dem neuen Mandanten
  /// direkt zugeordnet wird (manuelle Zuordnung beim Anlegen).
  final List<String> aktenOrdnernamen;

  /// Optionale Kfz-Kennzeichen des Mandanten, 0..n (mit Bindestrich).
  final List<String> kennzeichen;

  const CreateMandantRequest({
    this.anrede = Anrede.keine,
    this.vorname = '',
    this.nachname = '',
    this.strasseHausnummer = '',
    this.postleitzahl = '',
    this.ort = '',
    this.emailAdresse = '',
    this.telefonnummer = '',
    this.notiz = '',
    this.persoenlicheGrussformel = '',
    this.aktenOrdnernamen = const [],
    this.kennzeichen = const [],
  });

  @override
  List<Object?> get props => [
    anrede,
    vorname,
    nachname,
    strasseHausnummer,
    postleitzahl,
    ort,
    emailAdresse,
    telefonnummer,
    notiz,
    persoenlicheGrussformel,
    aktenOrdnernamen,
    kennzeichen,
  ];

  Map<String, dynamic> toJson() => {
    'anrede': anrede.value,
    'vorname': vorname,
    'nachname': nachname,
    'strasseHausnummer': strasseHausnummer,
    'postleitzahl': postleitzahl,
    'ort': ort,
    'emailAdresse': emailAdresse,
    'telefonnummer': telefonnummer,
    'notiz': notiz,
    'persoenlicheGrussformel': persoenlicheGrussformel,
    'aktenOrdnernamen': aktenOrdnernamen,
    'kennzeichen': kennzeichen,
  };
}
