import 'package:equatable/equatable.dart';

/// Ein aus Zentralruf-Antworten gelernter Versicherer (Wissensbasis). Das
/// Backend befüllt das Register automatisch mit jeder geparsten Antwort; die
/// Oberfläche nutzt es zum Füllen fehlender Felder und zur manuellen Auswahl
/// bei Negativ-Antworten. Spiegelt das Backend-DTO `VersichererDto`.
class Versicherer extends Equatable {
  final int id;
  final String name;
  final String? strasse;
  final String? plz;
  final String? ort;
  final String? telefon;
  final String? fax;
  final String? email;

  /// Wann das Backend den Eintrag zuletzt aus einer Antwort aktualisiert hat.
  final DateTime? zuletztAktualisiertAm;

  /// Herkunftshinweis, z. B. „Zentralruf-Antwort zur Anfrage vom 12.06.2026".
  final String? quelle;

  const Versicherer({
    required this.id,
    required this.name,
    this.strasse,
    this.plz,
    this.ort,
    this.telefon,
    this.fax,
    this.email,
    this.zuletztAktualisiertAm,
    this.quelle,
  });

  factory Versicherer.fromJson(Map<String, dynamic> json) {
    return Versicherer(
      id: json['id'] as int,
      name: json['name'] as String,
      strasse: json['strasse'] as String?,
      plz: json['plz'] as String?,
      ort: json['ort'] as String?,
      telefon: json['telefon'] as String?,
      fax: json['fax'] as String?,
      email: json['email'] as String?,
      zuletztAktualisiertAm: DateTime.tryParse(
        json['zuletztAktualisiertAm'] as String? ?? '',
      )?.toLocal(),
      quelle: json['quelle'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    strasse,
    plz,
    ort,
    telefon,
    fax,
    email,
    zuletztAktualisiertAm,
    quelle,
  ];
}
