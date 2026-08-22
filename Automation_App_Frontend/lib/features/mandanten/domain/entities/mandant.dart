import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:equatable/equatable.dart';

/// Ein Mandant der Kanzlei mit den wiederverwendbaren Stammdaten (§5.1).
/// Persistiert im Mandantenregister des Backends (SQLite); das Frontend hält
/// keine eigene Kopie. Die Verknüpfung zur Akte im Dateisystem (§6.1) läuft
/// über [aktenOrdnernamen]: die Namen der zugeordneten Ordner unter dem
/// Stammordner. Bewusst eine Liste, weil derselbe Mandant in der echten
/// Kanzlei mehrere Sachen/Ordner haben kann (z. B. eine Straf- und eine
/// Verkehrsunfallsache).
class Mandant extends Equatable {
  final int id;

  /// Anrede/Geschlecht für die korrekte Ansprache in Vorlagen und E-Mails.
  final Anrede anrede;
  final String vorname;
  final String nachname;
  final String strasseHausnummer;
  final String postleitzahl;
  final String ort;
  final String emailAdresse;
  final String telefonnummer;
  final String notiz;

  /// Namen der zugeordneten Akten-Ordner (relativ zum Stammordner), 0..n.
  final List<String> aktenOrdnernamen;

  /// Optionale Kfz-Kennzeichen des Mandanten, 0..n (mit Bindestrich, z. B.
  /// `HG-E 1427`). Ein Mandant kann mehrere Fahrzeuge halten.
  final List<String> kennzeichen;

  /// Zeitpunkt der Anlage im Register (ISO-8601), für Sortierung/Anzeige.
  final DateTime erstelltAm;

  const Mandant({
    required this.id,
    this.anrede = Anrede.keine,
    this.vorname = '',
    this.nachname = '',
    this.strasseHausnummer = '',
    this.postleitzahl = '',
    this.ort = '',
    this.emailAdresse = '',
    this.telefonnummer = '',
    this.notiz = '',
    this.aktenOrdnernamen = const [],
    this.kennzeichen = const [],
    required this.erstelltAm,
  });

  /// Anzeigename „Vorname Nachname"; fällt auf das Vorhandene zurück, wenn nur
  /// eines gesetzt ist.
  String get anzeigename => '$vorname $nachname'.trim();

  /// Vollständige Brief-/E-Mail-Anrede, z. B. „Sehr geehrter Herr Müller".
  /// Für Vorlagen und künftige E-Mails.
  String get briefanrede => anrede.briefanrede(nachname);

  factory Mandant.fromJson(Map<String, dynamic> json) {
    final ordner = json['aktenOrdnernamen'];
    final kz = json['kennzeichen'];
    return Mandant(
      id: json['id'] as int,
      anrede: Anrede.fromValue(json['anrede'] as String?),
      vorname: json['vorname'] as String? ?? '',
      nachname: json['nachname'] as String? ?? '',
      strasseHausnummer: json['strasseHausnummer'] as String? ?? '',
      postleitzahl: json['postleitzahl'] as String? ?? '',
      ort: json['ort'] as String? ?? '',
      emailAdresse: json['emailAdresse'] as String? ?? '',
      telefonnummer: json['telefonnummer'] as String? ?? '',
      notiz: json['notiz'] as String? ?? '',
      aktenOrdnernamen: ordner is List
          ? ordner.whereType<String>().toList()
          : const [],
      kennzeichen: kz is List ? kz.whereType<String>().toList() : const [],
      erstelltAm:
          DateTime.tryParse(json['erstelltAm'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'anrede': anrede.value,
    'vorname': vorname,
    'nachname': nachname,
    'strasseHausnummer': strasseHausnummer,
    'postleitzahl': postleitzahl,
    'ort': ort,
    'emailAdresse': emailAdresse,
    'telefonnummer': telefonnummer,
    'notiz': notiz,
    'aktenOrdnernamen': aktenOrdnernamen,
    'kennzeichen': kennzeichen,
    'erstelltAm': erstelltAm.toIso8601String(),
  };

  Mandant copyWith({
    Anrede? anrede,
    String? vorname,
    String? nachname,
    String? strasseHausnummer,
    String? postleitzahl,
    String? ort,
    String? emailAdresse,
    String? telefonnummer,
    String? notiz,
    List<String>? aktenOrdnernamen,
    List<String>? kennzeichen,
  }) {
    return Mandant(
      id: id,
      anrede: anrede ?? this.anrede,
      vorname: vorname ?? this.vorname,
      nachname: nachname ?? this.nachname,
      strasseHausnummer: strasseHausnummer ?? this.strasseHausnummer,
      postleitzahl: postleitzahl ?? this.postleitzahl,
      ort: ort ?? this.ort,
      emailAdresse: emailAdresse ?? this.emailAdresse,
      telefonnummer: telefonnummer ?? this.telefonnummer,
      notiz: notiz ?? this.notiz,
      aktenOrdnernamen: aktenOrdnernamen ?? this.aktenOrdnernamen,
      kennzeichen: kennzeichen ?? this.kennzeichen,
      erstelltAm: erstelltAm,
    );
  }

  @override
  List<Object?> get props => [
    id,
    anrede,
    vorname,
    nachname,
    strasseHausnummer,
    postleitzahl,
    ort,
    emailAdresse,
    telefonnummer,
    notiz,
    aktenOrdnernamen,
    kennzeichen,
    erstelltAm,
  ];
}
