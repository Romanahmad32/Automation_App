import 'package:automation_app/features/form_template_setup/domain/entities/platzhalter_gruppe.dart';

/// Explizite Datenquelle eines Vorlagenfelds: Womit das Feld beim Ausfüllen aus
/// dem gewählten [Vorgang] (Mandant + Zentralruf-Antwort + Vorgangsdaten)
/// vorbelegt wird. Ersetzt das fehleranfällige Raten über den Feldnamen — der
/// Anwalt ordnet jedem Feld die Quelle einmal eindeutig zu.
///
/// [keine] bedeutet: keine feste Zuordnung. Solche Felder löst
/// `FeldDatenquelleErkennung` beim Ausfüllen über den Feldnamen auf
/// (Abwärtskompatibilität für bestehende Vorlagen, die noch keine Quelle
/// gesetzt haben).
///
/// Die Aufteilung folgt einer Regel: **Was einzeln gespeichert ist, bekommt
/// eine eigene Quelle; Zusammensetzungen schreibt man als zwei Platzhalter
/// nebeneinander in die Word-Datei.** Einzige Ausnahme sind die Anschriften —
/// sie lassen fehlende Teile weg, was nebeneinandergesetzte Platzhalter nicht
/// können (sie hinterlassen dort eine Leerstelle).
///
/// **[platzhalter] ist der Rückweg** (§4.7, ergänzt am 02.09.2026): Bis dahin
/// führte nur ein Weg vom Namen zur Quelle (`FeldDatenquelleErkennung`), und
/// wer eine Vorlage schrieb, musste den Namen **raten**. Steht er hier am
/// Eintrag, lässt sich der Katalog zur Auswahl anbieten — und
/// `feld_datenquelle_test.dart` erzwingt, dass jeder angebotene Name über die
/// Erkennung wieder **auf diesen Eintrag** zurückführt. Damit kann die
/// angebotene Liste nicht mehr stillschweigend von der Auflösung abweichen:
/// Eine neue Datenquelle ohne Namen macht den Test rot.
enum FeldDatenquelle {
  keine(
    name: 'Keine (automatisch erraten)',
    value: 'keine',
    gruppe: PlatzhalterGruppe.ohne,
  ),

  // Mandant / Geschädigter (aus dem Mandantenregister bzw. dem Vorgang).
  mandantName(
    name: 'Mandant · Name',
    value: 'mandantName',
    platzhalter: 'MandantName',
    gruppe: PlatzhalterGruppe.mandant,
  ),
  mandantVorname(
    name: 'Mandant · Vorname',
    value: 'mandantVorname',
    platzhalter: 'MandantVorname',
    gruppe: PlatzhalterGruppe.mandant,
  ),
  mandantNachname(
    name: 'Mandant · Nachname',
    value: 'mandantNachname',
    platzhalter: 'MandantNachname',
    gruppe: PlatzhalterGruppe.mandant,
  ),
  mandantBriefanrede(
    name: 'Mandant · Briefanrede („Sehr geehrter Herr …“)',
    value: 'mandantBriefanrede',
    platzhalter: 'MandantBriefanrede',
    gruppe: PlatzhalterGruppe.mandant,
  ),
  mandantStrasse(
    name: 'Mandant · Straße & Hausnr.',
    value: 'mandantStrasse',
    platzhalter: 'MandantStrasse',
    gruppe: PlatzhalterGruppe.mandant,
  ),
  mandantPlz(
    name: 'Mandant · PLZ',
    value: 'mandantPlz',
    platzhalter: 'MandantPlz',
    gruppe: PlatzhalterGruppe.mandant,
  ),
  mandantOrt(
    name: 'Mandant · Ort',
    value: 'mandantOrt',
    platzhalter: 'MandantOrt',
    gruppe: PlatzhalterGruppe.mandant,
  ),
  mandantAnschrift(
    name: 'Mandant · Anschrift (Name, Straße, PLZ Ort)',
    value: 'mandantAnschrift',
    platzhalter: 'MandantAnschrift',
    gruppe: PlatzhalterGruppe.mandant,
  ),
  mandantEmail(
    name: 'Mandant · E-Mail',
    value: 'mandantEmail',
    platzhalter: 'MandantEmail',
    gruppe: PlatzhalterGruppe.mandant,
  ),
  mandantTelefon(
    name: 'Mandant · Telefon',
    value: 'mandantTelefon',
    platzhalter: 'MandantTelefon',
    gruppe: PlatzhalterGruppe.mandant,
  ),

  // Gegnerische Versicherung (aus der Zentralruf-Antwort).
  versichererName(
    name: 'Versicherer · Name',
    value: 'versichererName',
    platzhalter: 'VersichererName',
    gruppe: PlatzhalterGruppe.versicherer,
  ),
  versichererStrasse(
    name: 'Versicherer · Straße & Hausnr.',
    value: 'versichererStrasse',
    platzhalter: 'VersichererStrasse',
    gruppe: PlatzhalterGruppe.versicherer,
  ),
  versichererPlz(
    name: 'Versicherer · PLZ',
    value: 'versichererPlz',
    platzhalter: 'VersichererPlz',
    gruppe: PlatzhalterGruppe.versicherer,
  ),
  versichererOrt(
    name: 'Versicherer · Ort',
    value: 'versichererOrt',
    platzhalter: 'VersichererOrt',
    gruppe: PlatzhalterGruppe.versicherer,
  ),

  /// **Ohne Platzhalter, und das ist ein Mangel im Bestand**, kein Entwurf:
  /// `FeldDatenquelleErkennung` löst `adresse` *und* `anschrift` beide auf
  /// [versichererAnschrift] auf. Diese Quelle ist über einen Namen also gar
  /// nicht erreichbar — sie steht nur zur Verfügung, wenn sie am Vorlagenfeld
  /// ausdrücklich gewählt wird. Sie anzubieten hieße, die Form „ohne Name" zu
  /// versprechen und die mit Namen zu liefern.
  versichererAdresse(
    name: 'Versicherer · Adresse (Straße, PLZ Ort – ohne Name)',
    value: 'versichererAdresse',
    gruppe: PlatzhalterGruppe.versicherer,
  ),
  versichererAnschrift(
    name: 'Versicherer · Anschrift (Name, Straße, PLZ Ort)',
    value: 'versichererAnschrift',
    platzhalter: 'VersichererAnschrift',
    gruppe: PlatzhalterGruppe.versicherer,
  ),
  versichererEmail(
    name: 'Versicherer · E-Mail',
    value: 'versichererEmail',
    platzhalter: 'VersichererEmail',
    gruppe: PlatzhalterGruppe.versicherer,
  ),
  versichererTelefon(
    name: 'Versicherer · Telefon',
    value: 'versichererTelefon',
    platzhalter: 'VersichererTelefon',
    gruppe: PlatzhalterGruppe.versicherer,
  ),
  versichererFax(
    name: 'Versicherer · Fax',
    value: 'versichererFax',
    platzhalter: 'VersichererFax',
    gruppe: PlatzhalterGruppe.versicherer,
  ),
  versicherungsscheinNr(
    name: 'Versicherungsschein-Nr.',
    value: 'versicherungsscheinNr',
    platzhalter: 'VersicherungsscheinNr',
    gruppe: PlatzhalterGruppe.versicherer,
  ),
  versicherungsbeginn(
    name: 'Versicherungsbeginn',
    value: 'versicherungsbeginn',
    platzhalter: 'Versicherungsbeginn',
    gruppe: PlatzhalterGruppe.versicherer,
  ),

  // Vorgang / Unfall.
  /// Angeboten wird **`{{Gegnerkennzeichen}}`** (#58): „Kennzeichen" allein
  /// sagt nicht, wessen. Das blanke `{{Kennzeichen}}` löst weiter hierher auf,
  /// damit die Kanzleivorlagen im Bestand nicht brechen.
  kennzeichenGegner(
    name: 'Kennzeichen · Gegner',
    value: 'kennzeichenGegner',
    platzhalter: 'Gegnerkennzeichen',
    gruppe: PlatzhalterGruppe.vorgang,
  ),
  kennzeichenMandant(
    name: 'Kennzeichen · Mandant/Geschädigter',
    value: 'kennzeichenMandant',
    platzhalter: 'MandantKennzeichen',
    gruppe: PlatzhalterGruppe.vorgang,
  ),
  unfalldatum(
    name: 'Unfalldatum',
    value: 'unfalldatum',
    platzhalter: 'Unfalldatum',
    gruppe: PlatzhalterGruppe.vorgang,
  ),
  unfallort(
    name: 'Unfallort',
    value: 'unfallort',
    platzhalter: 'Unfallort',
    gruppe: PlatzhalterGruppe.vorgang,
  ),
  unfalluhrzeit(
    name: 'Unfalluhrzeit',
    value: 'unfalluhrzeit',
    platzhalter: 'Unfalluhrzeit',
    gruppe: PlatzhalterGruppe.vorgang,
  ),
  polizeiVorgangsnummer(
    name: 'Polizei-Vorgangsnummer',
    value: 'polizeiVorgangsnummer',
    platzhalter: 'PolizeiVorgangsnummer',
    gruppe: PlatzhalterGruppe.vorgang,
  ),
  referenz(
    name: 'Referenz (vollständig)',
    value: 'referenz',
    platzhalter: 'Referenz',
    gruppe: PlatzhalterGruppe.vorgang,
  ),

  /// **Ohne Platzhalter, solange der Restposten aus #38 offen ist:** Die
  /// Erkennung schickt `aktenzeichen` *und* `zeichen` auf [referenz], also auf
  /// die **volle** Referenz mit Kennzeichen (`84/26 C03_GG-XY 123`). Diese
  /// Quelle liefert die kurze Form und ist über einen Namen nicht erreichbar.
  /// Sie anzubieten hieße, „ohne Kennzeichen" zu versprechen und die lange
  /// Form zu liefern.
  aktenzeichen(
    name: 'Aktenzeichen (ohne Kennzeichen)',
    value: 'aktenzeichen',
    gruppe: PlatzhalterGruppe.vorgang,
  ),
  rechtsgebiet(
    name: 'Rechtsgebiet',
    value: 'rechtsgebiet',
    platzhalter: 'Rechtsgebiet',
    gruppe: PlatzhalterGruppe.vorgang,
  );

  final String name;

  /// Stabiler Schlüssel für die Persistenz (getrennt von [toString], gleiche
  /// Konvention wie [InputType]/[Rechtsgebiet]).
  final String value;

  /// Der Name, unter dem diese Quelle als `{{Platzhalter}}` **angeboten** wird.
  /// Leer heißt: nicht anbieten — der Eintrag sagt in seiner Doku, warum.
  final String platzhalter;

  /// Wohin der Eintrag in einer Auswahl gehört.
  final PlatzhalterGruppe gruppe;

  const FeldDatenquelle({
    required this.name,
    required this.value,
    required this.gruppe,
    this.platzhalter = '',
  });

  String get displayName => name;

  /// True für alles außer [keine] — also wenn eine feste Quelle gewählt wurde.
  bool get istGesetzt => this != FeldDatenquelle.keine;

  /// Ob diese Quelle als Platzhalter angeboten werden darf.
  bool get istWaehlbar => platzhalter.isNotEmpty;

  /// Der Platzhalter so, wie er in die Vorlage geschrieben wird.
  String get geschrieben => '{{$platzhalter}}';

  /// Alle Quellen, die als Platzhalter angeboten werden dürfen.
  static Iterable<FeldDatenquelle> get waehlbare =>
      FeldDatenquelle.values.where((quelle) => quelle.istWaehlbar);

  /// Liest eine [FeldDatenquelle] aus ihrem persistierten [value]. Unbekannte
  /// oder fehlende Werte fallen tolerant auf [keine] zurück, damit ein
  /// älterer/fremder Persistenzstand das Feld nicht unlesbar macht.
  static FeldDatenquelle fromValue(String? input) {
    for (final quelle in FeldDatenquelle.values) {
      if (quelle.value == input) return quelle;
    }
    return keine;
  }
}
