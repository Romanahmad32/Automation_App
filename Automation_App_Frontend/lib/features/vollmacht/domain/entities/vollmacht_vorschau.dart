import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Wie die Seitenvorschau ausgegangen ist — die Werte des Feldes `status` im
/// `VollmachtVorschauDto`.
enum VollmachtVorschauStatus {
  erstellt('erstellt'),
  vorlageFehlt('vorlageFehlt'),
  fehler('fehler');

  final String wert;

  const VollmachtVorschauStatus(this.wert);

  /// Ein unbekannter Wert ist ein [fehler].
  static VollmachtVorschauStatus ausWert(String? wert) {
    for (final status in values) {
      if (status.wert == wert) return status;
    }
    return fehler;
  }
}

/// Die ausgefüllte Vollmacht als Seite, so wie sie gedruckt würde (§4.11).
/// Der Dienst behält nichts davon — weder die Datei noch die PDF.
class VollmachtVorschau extends Equatable {
  final VollmachtVorschauStatus status;

  /// Die Seite als PDF, nur bei [VollmachtVorschauStatus.erstellt].
  final Uint8List? pdf;

  /// Klartext für den Anwalt, wenn es keine Seite gibt.
  final String? meldung;

  /// Platzhalter, die in der Vorlage stehen geblieben sind (§4.4).
  final List<String> warnungen;

  const VollmachtVorschau({
    required this.status,
    this.pdf,
    this.meldung,
    this.warnungen = const [],
  });

  factory VollmachtVorschau.fromJson(Map<String, dynamic> json) {
    final pdf = json['pdf'];
    return VollmachtVorschau(
      status: VollmachtVorschauStatus.ausWert(json['status'] as String?),
      pdf: pdf is String && pdf.isNotEmpty ? base64Decode(pdf) : null,
      meldung: json['meldung'] as String?,
      warnungen: [
        for (final warnung in json['warnungen'] as List? ?? const [])
          if (warnung is String) warnung,
      ],
    );
  }

  @override
  List<Object?> get props => [status, pdf, meldung, warnungen];
}
