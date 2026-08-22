/// Ergebnis des Aufräumens nach der Ablage in der Akte (§4.6).
///
/// Kein Erfolg heißt hier nicht „Ablage misslungen": das Dokument liegt zu dem
/// Zeitpunkt bereits in der Akte. Liegen bleibt nur die Arbeitskopie — meist,
/// weil sie noch in Word geöffnet ist.
class ArbeitsordnerAufraeumung {
  final bool erfolg;

  /// Erklärung des Dienstes, wenn etwas liegen blieb; sonst null.
  final String? meldung;

  const ArbeitsordnerAufraeumung({required this.erfolg, this.meldung});

  factory ArbeitsordnerAufraeumung.fromJson(Map<String, dynamic> json) =>
      ArbeitsordnerAufraeumung(
        erfolg: json['success'] as bool? ?? false,
        meldung: json['message'] as String?,
      );
}
