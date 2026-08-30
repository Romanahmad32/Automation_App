import 'package:equatable/equatable.dart';

/// Was der Register-Spiegel zuletzt getan hat (§6.2) — das Gegenstück zu
/// `RegisterSpiegelErgebnis`/`RegisterSpiegelDto` im Backend.
///
/// Bewusst nicht „Stand": So heißt im Backend die *Merkdatei*, die verhindert,
/// dass ein unveränderter Bestand zweimal geschrieben wird. Zwei Klassen
/// gleichen Namens auf beiden Seiten desselben Vertrags, die Verschiedenes
/// meinen, sind genau die Falle, in die eine Suche später läuft.
///
/// Der Spiegel ist die Word-/PDF-Fassung des Registers in einem einstellbaren
/// Ordner — liegt der im synchronisierten Bereich (OneDrive), ist das Register
/// unterwegs lesbar, ohne dass die App etwas von der Cloud wissen muss.
/// Geschrieben wird ausschließlich in der App; die Datei dort ist ein Spiegel
/// und kein zweites Original.
class RegisterSpiegelErgebnis extends Equatable {
  /// Ob in diesem Lauf Dateien entstanden sind.
  final bool geschrieben;

  /// Warum nicht geschrieben wurde — kein Ablageordner eingestellt, oder der
  /// Bestand ist unverändert. Null, wenn geschrieben wurde.
  final String? grund;

  /// Klartext, wenn das Schreiben scheiterte (fast immer: Die Datei ist noch
  /// in Word geöffnet). Null sonst.
  final String? fehler;

  final String? docxPfad;
  final String? pdfPfad;

  /// Warum das PDF fehlt, obwohl die Word-Datei steht. Auf einem Rechner ohne
  /// Word ist das erwartbar und kein Fehlschlag: Die `.docx` ist die
  /// verbindliche Fassung, das PDF die bequeme.
  final String? pdfFehler;

  final int zeilen;
  final DateTime? geschriebenAm;

  /// Dateien neben dem Spiegel, die nach einer Konfliktkopie des
  /// Synchronisierungsdienstes aussehen. Ihr Auftauchen heißt: Jemand hat den
  /// Spiegel unterwegs bearbeitet — ab da gäbe es zwei Register.
  final List<String> konfliktkopien;

  const RegisterSpiegelErgebnis({
    this.geschrieben = false,
    this.grund,
    this.fehler,
    this.docxPfad,
    this.pdfPfad,
    this.pdfFehler,
    this.zeilen = 0,
    this.geschriebenAm,
    this.konfliktkopien = const [],
  });

  /// Der Zustand vor dem ersten Abruf.
  static const RegisterSpiegelErgebnis unbekannt = RegisterSpiegelErgebnis();

  factory RegisterSpiegelErgebnis.fromJson(Map<String, dynamic> json) {
    final zeitpunkt = json['geschriebenAm'] as String?;
    return RegisterSpiegelErgebnis(
      geschrieben: json['geschrieben'] as bool? ?? false,
      grund: json['grund'] as String?,
      fehler: json['fehler'] as String?,
      docxPfad: json['docxPfad'] as String?,
      pdfPfad: json['pdfPfad'] as String?,
      pdfFehler: json['pdfFehler'] as String?,
      zeilen: (json['zeilen'] as num?)?.toInt() ?? 0,
      geschriebenAm: zeitpunkt == null ? null : DateTime.tryParse(zeitpunkt),
      konfliktkopien:
          (json['konfliktkopien'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  List<Object?> get props => [
    geschrieben,
    grund,
    fehler,
    docxPfad,
    pdfPfad,
    pdfFehler,
    zeilen,
    geschriebenAm,
    konfliktkopien,
  ];
}
