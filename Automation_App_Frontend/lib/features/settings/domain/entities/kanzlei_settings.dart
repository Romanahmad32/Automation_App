import 'package:equatable/equatable.dart';

/// Lokal gespeicherte App-Einstellungen: die Kanzlei-/Anfragerdaten, mit denen der
/// Abschnitt "Anfrager" des Zentralruf-Formulars vorausgefüllt wird, sowie
/// Dokument-Einstellungen für die Schadensaufstellung. Wird bei jeder Anfrage
/// mitgeschickt, damit das Backend zustandslos bleibt.
class KanzleiSettings extends Equatable {
  /// Standardfarbe der Titelzeile (Grau wie im Excel-Vorbild der Kanzlei).
  static const String defaultTabellenkopfFarbeHex = 'D9D9D9';

  /// Anfragertyp, der gilt, wenn nichts (Gültiges) gespeichert ist.
  static const String defaultPersonentyp = 'Rechtsanwalt';

  /// Abteilungskürzel für das Referenzformat, wenn nichts gespeichert ist.
  static const String defaultAbteilung = 'C03';

  /// Startwert der laufenden Auftragsnummer.
  static const int defaultLaufendeAuftragsnummer = 1;

  /// Die Anfragertypen exakt so, wie sie das Dropdown des Zentralruf-Formulars
  /// anbietet — das Backend wählt die Option über diesen Beschriftungstext aus.
  static const List<String> gueltigePersonentypen = [
    'Persönlicher Vertreter',
    'Rechtsanwalt',
    'Autovermietung',
    'Reparaturwerkstatt',
    'Sachverständiger',
    'Versicherung',
    'Makler od. sonst. Vers.',
    'Krankenkasse',
    'Ausl. Auskunftsstelle',
    'Rehabilitation',
  ];

  final String personentyp;
  final String name;
  final String strasseHausnummer;
  final String postleitzahl;
  final String ort;
  final String emailAdresse;
  final String telefonnummer;

  /// Laufende Auftragsnummer für das Referenzformat (z. B. 84). Wird in jedes
  /// "Auftragsnummer"-Feld vorausgefüllt und nach Abschluss eines Auftrags
  /// hochgezählt (§7.1).
  final int laufendeAuftragsnummer;

  /// Abteilungskürzel für das Referenzformat (z. B. "C03").
  final String abteilung;

  /// Hintergrundfarbe der Titelzeile der Schadensaufstellungs-Tabelle
  /// als Hex-Wert "RRGGBB" (ohne '#').
  final String tabellenkopfFarbeHex;

  /// Stammordner des Aktensystems im Dateisystem (§6.1, §7.1). Unter diesem
  /// Ordner liegt pro Mandant eine Akte (Unterordner). Leer = noch nicht
  /// festgelegt; ohne Stammordner ist die automatische Ablage nicht möglich.
  /// Bewusst kein Default-Pfad: Die App läuft auf einem fremden Rechner.
  final String aktenStammordner;

  /// Signaturblock unter dem Mailtext beim Direktversand (§4.7). Einmal aus
  /// dem Mailprogramm übernommen, danach hier gepflegt. Beim Entwurf in
  /// Outlook ungenutzt — dort setzt Outlook seine eigene ein.
  final String mailSignatur;

  /// Die formatierte Fassung derselben Signatur (§4.7): Schrift, Farben, Logo.
  /// Die App **reicht sie nur durch** — übernommen und geändert wird sie im
  /// Dienst (`POST api/EmailVersand/signaturen/uebernehmen`), weil dabei auch
  /// Bilder abzulegen sind. Hier steht sie, damit ein Speichern der
  /// Einstellungen sie nicht mitlöscht.
  final String mailSignaturHtml;

  const KanzleiSettings({
    this.personentyp = 'Rechtsanwalt',
    this.name = '',
    this.strasseHausnummer = '',
    this.postleitzahl = '',
    this.ort = '',
    this.emailAdresse = '',
    this.telefonnummer = '',
    this.laufendeAuftragsnummer = defaultLaufendeAuftragsnummer,
    this.abteilung = defaultAbteilung,
    this.tabellenkopfFarbeHex = defaultTabellenkopfFarbeHex,
    this.aktenStammordner = '',
    this.mailSignatur = '',
    this.mailSignaturHtml = '',
  });

  static const KanzleiSettings empty = KanzleiSettings();

  KanzleiSettings copyWith({
    String? personentyp,
    String? name,
    String? strasseHausnummer,
    String? postleitzahl,
    String? ort,
    String? emailAdresse,
    String? telefonnummer,
    int? laufendeAuftragsnummer,
    String? abteilung,
    String? tabellenkopfFarbeHex,
    String? aktenStammordner,
    String? mailSignatur,
    String? mailSignaturHtml,
  }) {
    return KanzleiSettings(
      personentyp: personentyp ?? this.personentyp,
      name: name ?? this.name,
      strasseHausnummer: strasseHausnummer ?? this.strasseHausnummer,
      postleitzahl: postleitzahl ?? this.postleitzahl,
      ort: ort ?? this.ort,
      emailAdresse: emailAdresse ?? this.emailAdresse,
      telefonnummer: telefonnummer ?? this.telefonnummer,
      laufendeAuftragsnummer:
          laufendeAuftragsnummer ?? this.laufendeAuftragsnummer,
      abteilung: abteilung ?? this.abteilung,
      tabellenkopfFarbeHex: tabellenkopfFarbeHex ?? this.tabellenkopfFarbeHex,
      aktenStammordner: aktenStammordner ?? this.aktenStammordner,
      mailSignatur: mailSignatur ?? this.mailSignatur,
      mailSignaturHtml: mailSignaturHtml ?? this.mailSignaturHtml,
    );
  }

  factory KanzleiSettings.fromJson(Map<String, dynamic> json) {
    // Früher war der Personentyp ein Freitextfeld; ungültige Altwerte werden
    // beim Laden bereinigt, damit das Zentralruf-Dropdown sie sicher findet.
    final personentyp = json['personentyp'] as String? ?? defaultPersonentyp;
    return KanzleiSettings(
      personentyp: gueltigePersonentypen.contains(personentyp)
          ? personentyp
          : defaultPersonentyp,
      name: json['name'] as String? ?? '',
      strasseHausnummer: json['strasseHausnummer'] as String? ?? '',
      postleitzahl: json['postleitzahl'] as String? ?? '',
      ort: json['ort'] as String? ?? '',
      emailAdresse: json['emailAdresse'] as String? ?? '',
      telefonnummer: json['telefonnummer'] as String? ?? '',
      laufendeAuftragsnummer:
          (json['laufendeAuftragsnummer'] as num?)?.toInt() ??
          defaultLaufendeAuftragsnummer,
      abteilung: json['abteilung'] as String? ?? defaultAbteilung,
      tabellenkopfFarbeHex:
          json['tabellenkopfFarbeHex'] as String? ??
          defaultTabellenkopfFarbeHex,
      aktenStammordner: json['aktenStammordner'] as String? ?? '',
      mailSignatur: json['mailSignatur'] as String? ?? '',
      mailSignaturHtml: json['mailSignaturHtml'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'personentyp': personentyp,
    'name': name,
    'strasseHausnummer': strasseHausnummer,
    'postleitzahl': postleitzahl,
    'ort': ort,
    'emailAdresse': emailAdresse,
    'telefonnummer': telefonnummer,
    'laufendeAuftragsnummer': laufendeAuftragsnummer,
    'abteilung': abteilung,
    'tabellenkopfFarbeHex': tabellenkopfFarbeHex,
    'aktenStammordner': aktenStammordner,
    'mailSignatur': mailSignatur,
    'mailSignaturHtml': mailSignaturHtml,
  };

  @override
  List<Object?> get props => [
    personentyp,
    name,
    strasseHausnummer,
    postleitzahl,
    ort,
    emailAdresse,
    telefonnummer,
    laufendeAuftragsnummer,
    abteilung,
    tabellenkopfFarbeHex,
    aktenStammordner,
    mailSignatur,
    mailSignaturHtml,
  ];
}
