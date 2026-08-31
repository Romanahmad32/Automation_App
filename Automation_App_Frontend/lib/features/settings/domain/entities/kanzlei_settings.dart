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

  /// Basisname der Register-Spiegeldateien ohne Endung (§6.2). Der Zusatz
  /// „(App)" ist kein Schmuck: Die Datei landet in aller Regel in demselben
  /// synchronisierten Ordner wie das gewachsene Kanzleidokument und muss auf
  /// den ersten Blick von ihm zu unterscheiden sein.
  static const String defaultRegisterDateiname = 'Sachgebiete-Register (App)';

  /// Alle Vorgänge kommen in die Spiegeldatei.
  static const String registerFilterAlle = 'alle';

  /// Nur abgeschlossene (versendete) Vorgänge kommen in die Spiegeldatei.
  static const String registerFilterAbgeschlossen = 'abgeschlossen';

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

  /// Zielordner des Register-Spiegels (§6.2). Gedacht ist ein Ordner im
  /// synchronisierten Bereich (OneDrive), damit das Register unterwegs lesbar
  /// ist — gespeichert wird aber ein ganz gewöhnlicher Pfad: Die App kennt
  /// keine Cloud, sie legt eine Datei ab und der Client synchronisiert.
  /// Leer heißt: kein Spiegel.
  final String registerAblageOrdner;

  /// Basisname der Spiegeldateien ohne Endung; daraus entstehen `.docx` und
  /// `.pdf`. Bewusst nicht der Name des gewachsenen Kanzleidokuments — das
  /// bleibt unangetastet liegen.
  final String registerDateiname;

  /// Ob der Spiegel nach jedem Vorgangsabschluss neu geschrieben wird.
  final bool registerNachAbschlussSchreiben;

  /// Was in die Datei kommt: [registerFilterAlle] oder
  /// [registerFilterAbgeschlossen]. Bewusst eine Einstellung und nicht der
  /// Filter der Ansicht — sonst hinge der Inhalt der Datei davon ab, was
  /// gerade am Bildschirm eingestellt war.
  final String registerExportFilter;

  /// Ordner, in dem die Word-Vorlagen des Anwalts liegen. Leer = der
  /// App-Ordner des Backends unter %APPDATA% (der Stand vor dieser
  /// Einstellung). Maschinenabhängig wie [aktenStammordner]: wird beim
  /// Einspielen einer Sicherung nicht übernommen. Bewusst kein Default-Pfad —
  /// die App läuft auf einem fremden Rechner.
  final String vorlagenOrdner;

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
    this.registerAblageOrdner = '',
    this.registerDateiname = defaultRegisterDateiname,
    this.registerNachAbschlussSchreiben = true,
    this.registerExportFilter = registerFilterAlle,
    this.vorlagenOrdner = '',
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
    String? registerAblageOrdner,
    String? registerDateiname,
    bool? registerNachAbschlussSchreiben,
    String? registerExportFilter,
    String? vorlagenOrdner,
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
      registerAblageOrdner: registerAblageOrdner ?? this.registerAblageOrdner,
      registerDateiname: registerDateiname ?? this.registerDateiname,
      registerNachAbschlussSchreiben:
          registerNachAbschlussSchreiben ?? this.registerNachAbschlussSchreiben,
      registerExportFilter: registerExportFilter ?? this.registerExportFilter,
      vorlagenOrdner: vorlagenOrdner ?? this.vorlagenOrdner,
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
      registerAblageOrdner: json['registerAblageOrdner'] as String? ?? '',
      registerDateiname:
          json['registerDateiname'] as String? ?? defaultRegisterDateiname,
      registerNachAbschlussSchreiben:
          json['registerNachAbschlussSchreiben'] as bool? ?? true,
      registerExportFilter:
          json['registerExportFilter'] as String? ?? registerFilterAlle,
      vorlagenOrdner: json['vorlagenOrdner'] as String? ?? '',
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
    'registerAblageOrdner': registerAblageOrdner,
    'registerDateiname': registerDateiname,
    'registerNachAbschlussSchreiben': registerNachAbschlussSchreiben,
    'registerExportFilter': registerExportFilter,
    'vorlagenOrdner': vorlagenOrdner,
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
    registerAblageOrdner,
    registerDateiname,
    registerNachAbschlussSchreiben,
    registerExportFilter,
    vorlagenOrdner,
  ];
}
