import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/input_type.dart';

/// Was die Erkennung zu einem Platzhalternamen sagt: die vorgeschlagene
/// [FeldDatenquelle], der dazu passende [InputType] und — wenn bewusst *nicht*
/// gebunden wurde — der Grund dafür.
///
/// [hinweis] ist der Sinn der Sache: `{{VersicherungPlzOrt}}` meint zwei
/// Angaben und lieferte früher still nur die PLZ. Jetzt bleibt der Platzhalter
/// ungebunden und sagt im Vorlageneditor, warum — der Fehler wird einmal beim
/// Einrichten sichtbar, statt in jedem erzeugten Brief unsichtbar zu bleiben.
class DatenquelleVorschlag {
  final FeldDatenquelle quelle;
  final InputType inputType;

  /// Satz für den Vorlageneditor, wenn der Name nach Daten klingt, aber nicht
  /// gebunden werden konnte. Null heißt: nichts zu erklären.
  final String? hinweis;

  const DatenquelleVorschlag({
    required this.quelle,
    this.inputType = InputType.text,
    this.hinweis,
  });
}

/// Löst einen frei gewählten Platzhalternamen zu einer [FeldDatenquelle] auf —
/// die eine Stelle, an der aus einem Namen eine Datenquelle wird.
///
/// Sie wird an zwei Stellen gebraucht, und das ist der Punkt: beim
/// **Einrichten** der Vorlage (Vorauswahl im Dropdown, sichtbar und änderbar —
/// §1.3) und zur **Laufzeit** für Felder, deren Quelle nie gesetzt wurde
/// (`VorgangPrefillMatcher`, Abwärtskompatibilität bestehender Vorlagen).
/// Vorher waren das zwei getrennte Wortlisten mit eigener Prüfreihenfolge, die
/// auseinanderliefen: Was der Anwalt im Dropdown sah, war etwas anderes als
/// das, was beim Ausfüllen tatsächlich passierte.
///
/// **Die Reihenfolge der Prüfungen ist die Regel** — spezifisch vor allgemein.
/// Wer eine Zeile verschiebt, ändert das Verhalten.
class FeldDatenquelleErkennung {
  const FeldDatenquelleErkennung._();

  /// Vergleichsform eines Feldnamens: Kleinschreibung, Umlaute ausgeschrieben,
  /// alles außer `a–z0–9` entfernt. Damit sind `{{Zahlungs-Frist}}`,
  /// `{{Zahlungsfrist}}` und `{{ZAHLUNGSFRIST}}` derselbe Name.
  ///
  /// Öffentlich, weil außerhalb dieser Klasse nach denselben Regeln verglichen
  /// wird (etwa die Datums-Vorbelegung in `form_template_builder.dart`) — zwei
  /// Normalisierungen nebeneinander wären genau der Zustand, den diese Klasse
  /// aufräumt.
  static String normalisiere(String name) => name
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Vorschlag zu einem Platzhalternamen. [FeldDatenquelle.keine], wenn nichts
  /// eindeutig passt — statt den nächstbesten Treffer zu nehmen.
  ///
  /// Ein Vorschlag bleibt ein Vorschlag: Er steht sichtbar im Dropdown und ist
  /// änderbar, nichts wird stillschweigend gebunden (§1.3, „Vorschlagen statt
  /// entscheiden").
  static DatenquelleVorschlag erkenne(String name) {
    final normalisiert = normalisiere(name);
    final hinweis = _mehrdeutigkeit(normalisiert);
    if (hinweis != null) {
      return DatenquelleVorschlag(
        quelle: FeldDatenquelle.keine,
        hinweis: hinweis,
      );
    }
    return DatenquelleVorschlag(
      quelle: _quelleFuer(normalisiert),
      inputType: _feldtypFuer(normalisiert),
    );
  }

  /// Nur die Quelle — der Weg, den die Laufzeit-Vorbelegung nimmt.
  static FeldDatenquelle quelleFuer(String name) => erkenne(name).quelle;

  /// Ein neues Vorlagenfeld aus einem übernommenen Platzhalter: Feldtyp und
  /// Datenquelle stehen im Editor vorausgewählt, sichtbar und änderbar.
  ///
  /// [controlKey] ist der Schlüssel des reactive_forms-Controls, unter dem der
  /// Feldname liegt, solange die Detailseite offen ist (siehe FEATURE.md) —
  /// deshalb wird der Name getrennt als [platzhalter] übergeben.
  static FieldData neuesFeld({
    required int order,
    required String controlKey,
    String? platzhalter,
    bool required = false,
  }) {
    final vorschlag = erkenne(platzhalter ?? '');
    return FieldData(
      order: order,
      label: controlKey,
      required: required,
      inputType: vorschlag.inputType,
      datenquelle: vorschlag.quelle,
    );
  }

  /// Angaben, die einzeln gespeichert sind und deshalb einzeln in die Vorlage
  /// gehören. Nennt ein Name zwei davon, meint er zwei Werte — und ein Feld
  /// kann nur einen liefern.
  ///
  /// Die Alternative wäre je Kombination eine eigene Datenquelle („PLZ Ort",
  /// „Name und Straße", …). Das ließe den Wortschatz mit jedem Layoutwunsch
  /// wachsen, obwohl zwei Platzhalter nebeneinander in derselben Word-Zeile
  /// dasselbe leisten.
  static List<String> _atomeIn(String name) => [
    if (name.contains('vorname')) 'Vorname',
    if (name.contains('nachname') || name.contains('familienname')) 'Nachname',
    if (name.contains('strasse') || name.contains('hausnummer')) 'Straße',
    if (name.contains('plz') || name.contains('postleitzahl')) 'PLZ',
    if (_meintOrt(name)) 'Ort',
  ];

  static String? _mehrdeutigkeit(String name) {
    final atome = _atomeIn(name);
    if (atome.length < 2) return null;
    return 'Dieser Platzhalter meint mehrere Angaben (${atome.join(' und ')}) '
        'und bleibt deshalb ungebunden. Teile ihn in je einen Platzhalter — '
        'nebeneinander in der Word-Datei ergeben sie dieselbe Zeile.';
  }

  /// „Ort" ja, „Vorort" nein — dieselbe Ausnahme wie bisher in beiden
  /// abgelösten Heuristiken.
  static bool _meintOrt(String name) =>
      name.contains('ort') && !name.contains('vorort');

  /// Ein Datumsfeld erkennt man am Namen, nicht an der Datenquelle: auch ein
  /// ungebundenes `{{Zahlungsfrist}}` ist ein Datum.
  static InputType _feldtypFuer(String name) {
    const datumsWorte = ['datum', 'tag', 'frist', 'beginn'];
    return datumsWorte.any(name.contains) ? InputType.date : InputType.text;
  }

  static FeldDatenquelle _quelleFuer(String name) {
    bool hat(String wort) => name.contains(wort);

    // Der Unfall steht vor den Beteiligten: „Unfallort des Geschädigten" meint
    // den Ort des Unfalls, nicht den Wohnort des Mandanten. Käme die
    // Mandantengruppe zuerst, fischte deren „ort" diesen Namen ab und das
    // Schreiben trüge still den falschen Ort. Keines dieser Wörter benennt je
    // eine Stammdatenangabe, deshalb dürfen sie ganz nach vorn.
    if (hat('unfallort')) return FeldDatenquelle.unfallort;
    if (hat('unfalluhrzeit') || hat('unfallzeit')) {
      return FeldDatenquelle.unfalluhrzeit;
    }
    if (hat('polizei')) return FeldDatenquelle.polizeiVorgangsnummer;
    if (hat('unfalldatum') ||
        hat('unfalltag') ||
        hat('schadentag') ||
        hat('verkehrsunfall')) {
      return FeldDatenquelle.unfalldatum;
    }

    // Alles Übrige, was den Mandanten/Geschädigten nennt, kommt aus dem
    // Register — nie aus der Zentralruf-Antwort, die kennt seine Daten nicht.
    if (hat('mandant') || hat('geschaedigt') || hat('kunde')) {
      return _mandantenfeld(name);
    }

    if (hat('rechtsgebiet') || hat('sachgebiet')) {
      return FeldDatenquelle.rechtsgebiet;
    }
    if (hat('versicherungsschein') ||
        hat('scheinnr') ||
        hat('schadennummer') ||
        hat('schadensnummer')) {
      return FeldDatenquelle.versicherungsscheinNr;
    }
    if (hat('versicherungsbeginn')) return FeldDatenquelle.versicherungsbeginn;
    // Ein Kennzeichen ohne Mandantenbezug ist das des Gegners — Referenz und
    // Antwort kennen nur dieses. Der angebotene Name ist „Gegnerkennzeichen"
    // (§4.1), aber die Prüfung bleibt ein *Teilstring*-Test: Vorlagen aus der
    // Zeit davor tragen das blanke `{{Kennzeichen}}`, und ein exakter
    // Vergleich ließe sie still auf leer fallen — kein Fehler, keine Meldung,
    // nur ein fehlender Wert im Brief. `feld_datenquelle_erkennung_test.dart`
    // hält beide Schreibweisen fest.
    if (hat('kennzeichen')) return FeldDatenquelle.kennzeichenGegner;
    // „Zeichen" und „Aktenzeichen" meinen dasselbe und stehen im Brief ohne
    // Kennzeichen („216/26 C03"). Nur wer ausdrücklich „Referenz" schreibt,
    // will die volle Zeichenkette samt Kennzeichen — die braucht sonst nur
    // der Zentralruf (§4.2).
    if (hat('aktenzeichen') || name == 'zeichen') {
      return FeldDatenquelle.zeichen;
    }
    if (hat('referenz')) return FeldDatenquelle.referenz;
    if (hat('versicher') || hat('gegner') || hat('empfaenger')) {
      return _versichererfeld(name);
    }
    // Ein einzelnes E-Mail-Feld meint in diesem Ablauf den Empfänger des
    // Anspruchsschreibens, also die gegnerische Versicherung.
    if (hat('mail')) return FeldDatenquelle.versichererEmail;
    return FeldDatenquelle.keine;
  }

  static FeldDatenquelle _mandantenfeld(String name) {
    bool hat(String wort) => name.contains(wort);

    // Gegenstück zum Gegnerkennzeichen: „Mandantenkennzeichen" trägt seinen
    // Bezug im Namen und landet über ihn schon hier; „Mandant Kennzeichen" aus
    // dem Bestand ebenso.
    if (hat('kennzeichen')) return FeldDatenquelle.kennzeichenMandant;
    if (hat('vorname')) return FeldDatenquelle.mandantVorname;
    if (hat('nachname') || hat('familienname')) {
      return FeldDatenquelle.mandantNachname;
    }
    if (hat('anrede')) return FeldDatenquelle.mandantBriefanrede;
    if (hat('strasse') || hat('hausnummer')) {
      return FeldDatenquelle.mandantStrasse;
    }
    if (hat('plz') || hat('postleitzahl')) return FeldDatenquelle.mandantPlz;
    if (_meintOrt(name)) return FeldDatenquelle.mandantOrt;
    if (hat('mail')) return FeldDatenquelle.mandantEmail;
    if (hat('telefon') || hat('tel')) return FeldDatenquelle.mandantTelefon;
    if (hat('anschrift') || hat('adresse')) {
      return FeldDatenquelle.mandantAnschrift;
    }
    return FeldDatenquelle.mandantName;
  }

  /// Dieselbe Staffelung wie beim Mandanten, damit „Ort des Mandanten" und
  /// „Ort der Versicherung" nicht nach verschiedenen Regeln aufgelöst werden.
  static FeldDatenquelle _versichererfeld(String name) {
    bool hat(String wort) => name.contains(wort);

    if (hat('strasse') || hat('hausnummer')) {
      return FeldDatenquelle.versichererStrasse;
    }
    if (hat('plz') || hat('postleitzahl')) {
      return FeldDatenquelle.versichererPlz;
    }
    if (_meintOrt(name)) return FeldDatenquelle.versichererOrt;
    if (hat('mail')) return FeldDatenquelle.versichererEmail;
    if (hat('telefon') || hat('tel')) return FeldDatenquelle.versichererTelefon;
    if (hat('fax')) return FeldDatenquelle.versichererFax;
    if (hat('anschrift') || hat('adresse')) {
      return FeldDatenquelle.versichererAnschrift;
    }
    return FeldDatenquelle.versichererName;
  }
}
