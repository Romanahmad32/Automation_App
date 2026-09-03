import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';

/// Gebündelte, bereits typisierte Eingaben des „Vorgang starten"-Formulars.
/// Trennt das Auslesen der Reactive-Forms-Controls (View) von der
/// Weiterverarbeitung (Bloc) und kapselt die Mandanten-Ableitungen, damit View
/// und Bloc schlank bleiben.
class VorgangStartenDaten {
  final int auftragsnummer;
  final int auftragsjahr;
  final String abteilung;
  final String rechtsgebiet;

  /// Die in der Vorschau angezeigte (ggf. manuell bearbeitete) Referenz.
  final String referenz;

  // Mandantendaten (Geschädigter im Verkehrsunfall).
  final String vorname;
  final String nachname;
  final String strasseHausnummer;
  final String postleitzahl;
  final String ort;
  final String emailAdresse;
  final String telefonnummer;
  final String mandantKennzeichen;

  // Unfalldaten (nur bei Verkehrsrecht erfasst).
  final String kennzeichenGegner;
  final DateTime? unfalltag;
  final String unfallort;
  final String unfalluhrzeit;
  final String polizeiVorgangsnummer;

  const VorgangStartenDaten({
    required this.auftragsnummer,
    required this.auftragsjahr,
    required this.abteilung,
    required this.rechtsgebiet,
    required this.referenz,
    this.vorname = '',
    this.nachname = '',
    this.strasseHausnummer = '',
    this.postleitzahl = '',
    this.ort = '',
    this.emailAdresse = '',
    this.telefonnummer = '',
    this.mandantKennzeichen = '',
    this.kennzeichenGegner = '',
    this.unfalltag,
    this.unfallort = '',
    this.unfalluhrzeit = '',
    this.polizeiVorgangsnummer = '',
  });

  bool get istVerkehrsunfall => RechtsgebietWert.istVerkehrsrecht(rechtsgebiet);

  /// Anzeigename „Vorname Nachname"; leer, wenn keine Namensteile erfasst sind.
  String get mandantName => '$vorname $nachname'.trim();

  /// Ob überhaupt Mandantendaten (mindestens ein Name) erfasst wurden.
  bool get hatMandantDaten => mandantName.isNotEmpty;

  /// Unfalltag im deutschen Format `TT.MM.JJJJ` für die Vorgangs-Persistenz.
  String? get unfallDatumText {
    final tag = unfalltag;
    if (tag == null) return null;
    return deutschesDatum(tag);
  }

  /// Leeren String zu null normalisieren (für optionale Persistenzfelder).
  static String? leerZuNull(String wert) =>
      wert.trim().isEmpty ? null : wert.trim();

  /// Baut die Anlage-Anfrage für einen neuen Mandanten aus den Eingaben.
  CreateMandantRequest toCreateRequest() => CreateMandantRequest(
    vorname: vorname,
    nachname: nachname,
    strasseHausnummer: strasseHausnummer,
    postleitzahl: postleitzahl,
    ort: ort,
    emailAdresse: emailAdresse,
    telefonnummer: telefonnummer,
    kennzeichen: mandantKennzeichen.trim().isEmpty
        ? const []
        : [mandantKennzeichen.trim()],
  );

  /// Mergt die erfassten Werte in den bestehenden Mandanten (für die
  /// Aktualisierung); ein neues Kennzeichen wird ergänzt, vorhandene bleiben.
  Mandant applyTo(Mandant original) => original.copyWith(
    vorname: vorname,
    nachname: nachname,
    strasseHausnummer: strasseHausnummer,
    postleitzahl: postleitzahl,
    ort: ort,
    emailAdresse: emailAdresse,
    telefonnummer: telefonnummer,
    kennzeichen: _gemergteKennzeichen(original.kennzeichen),
  );

  /// True, wenn die Eingaben vom gespeicherten Mandanten abweichen (Auslöser für
  /// den „Daten aktualisieren?"-Dialog).
  bool weichtAbVon(Mandant m) {
    final neuesKennzeichen = mandantKennzeichen.trim();
    final kennzeichenNeu =
        neuesKennzeichen.isNotEmpty &&
        !m.kennzeichen.any(
          (k) => k.trim().toUpperCase() == neuesKennzeichen.toUpperCase(),
        );
    return vorname.trim() != m.vorname.trim() ||
        nachname.trim() != m.nachname.trim() ||
        strasseHausnummer.trim() != m.strasseHausnummer.trim() ||
        postleitzahl.trim() != m.postleitzahl.trim() ||
        ort.trim() != m.ort.trim() ||
        emailAdresse.trim() != m.emailAdresse.trim() ||
        telefonnummer.trim() != m.telefonnummer.trim() ||
        kennzeichenNeu;
  }

  List<String> _gemergteKennzeichen(List<String> vorhanden) {
    final neu = mandantKennzeichen.trim();
    if (neu.isEmpty) return vorhanden;
    final schonDa = vorhanden.any(
      (k) => k.trim().toUpperCase() == neu.toUpperCase(),
    );
    return schonDa ? vorhanden : [...vorhanden, neu];
  }
}
