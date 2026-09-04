import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/form_template_setup/domain/services/feld_datenquelle_erkennung.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/mandant_anschrift.dart';

/// Ordnet die in einem [Vorgang] gebündelten Daten (Mandant + Zentralruf-Antwort
/// + Vorgangsfelder) den frei benannten Feldern einer Formularvorlage zu.
///
/// Eine Kette, nicht mehrere Wege: **Name → Datenquelle → Wert.** Ist am Feld
/// eine [FeldDatenquelle] gewählt, gilt sie; sonst löst
/// [FeldDatenquelleErkennung] den Namen zu einer Quelle auf. Danach nimmt
/// *jedes* Feld denselben Weg durch [_ausDatenquelle].
///
/// Vorher liefen hier zwei weitere Zuordnungen mit eigenen Wortlisten daneben
/// (eine für die Mandantenfelder, dazu der abgeschaffte
/// `VorgangsdatenFieldMatcher` für die Antwortfelder). Sie kannten
/// jeweils nur einen Teil der Daten: Unfallort, Unfalluhrzeit und
/// Polizei-Vorgangsnummer hatten gar keine Entsprechung, und Unfalldatum,
/// Kennzeichen und Referenz kamen ausschließlich aus der Antwort — ohne
/// übernommene Antwort blieben sie leer, obwohl der Vorgang sie kannte.
///
/// Felder ohne Zuordnung bleiben leer — lieber unbefüllt als falsch vorbelegt
/// (§1.3). Jeder Wert trägt seine Herkunft ([PrefillWert]) für die Anzeige am
/// Feld, damit der Anwalt falsche Vorbelegungen sofort erkennt.
class VorgangPrefillMatcher {
  const VorgangPrefillMatcher._();

  /// Liefert je Feld den vorzubelegenden Wert (ohne Herkunft) — bequemer
  /// Zugriff auf [matchTemplateFieldsMitHerkunft] für Aufrufer, die nur die
  /// Werte brauchen.
  static Map<String, String> matchTemplateFields(
    List<FieldData> fields,
    Vorgang vorgang, {
    Mandant? mandant,
  }) {
    return matchTemplateFieldsMitHerkunft(
      fields,
      vorgang,
      mandant: mandant,
    ).map((label, wert) => MapEntry(label, wert.wert));
  }

  /// Liefert je Feld den vorzubelegenden Wert samt Herkunft.
  ///
  /// Wurde zum Vorgang schon einmal ein Dokument erzeugt, gewinnen die dabei
  /// bestätigten Werte ([Vorgang.feldWerte]) über die Datenquelle — der Anwalt
  /// hat sie bereits gesehen und abgesegnet (Rückfluss, siehe
  /// VorgangRueckfluss).
  static Map<String, PrefillWert> matchTemplateFieldsMitHerkunft(
    List<FieldData> fields,
    Vorgang vorgang, {
    Mandant? mandant,
  }) {
    final result = <String, PrefillWert>{};

    for (final field in fields) {
      final quelle = field.datenquelle.istGesetzt
          ? field.datenquelle
          : FeldDatenquelleErkennung.quelleFuer(field.label);
      final wert = _ausDatenquelle(quelle, vorgang, mandant);
      if (wert != null && wert.isNotEmpty) {
        result[field.label] = PrefillWert(
          wert,
          _quelleFuerDatenquelle(quelle, vorgang, mandant),
        );
      }
    }

    // Zuletzt bestätigte Werte des Vorgangs haben höchste Priorität (nur für
    // Felder der aktuellen Vorlage; leere Werte überschreiben nichts).
    final gespeichert = vorgang.feldWerte;
    if (gespeichert != null) {
      for (final field in fields) {
        final wert = gespeichert[field.label]?.trim();
        if (wert != null && wert.isNotEmpty) {
          result[field.label] = PrefillWert(wert, PrefillQuelle.gespeichert);
        }
      }
    }
    return result;
  }

  /// Löst einen Platzhalternamen gegen die Daten des Vorgangs auf — dieselbe
  /// Kette wie beim Ausfüllen einer Formularvorlage: **Name → Datenquelle →
  /// Wert**.
  ///
  /// Für die Mail-Textvorlagen (§4.7), die dieselbe Schreibweise `{{Name}}`
  /// benutzen. Sie hier mitzubenutzen statt daneben eine zweite Ersetzung zu
  /// bauen ist der ganze Punkt: Zwei Kataloge liefen auseinander, und der
  /// Anwalt müsste sich merken, welcher wo gilt.
  static String? wertFuerNamen(
    String name,
    Vorgang vorgang, {
    Mandant? mandant,
  }) => _ausDatenquelle(
    FeldDatenquelleErkennung.quelleFuer(name),
    vorgang,
    mandant,
  );

  /// Löst eine [FeldDatenquelle] gegen die Daten des Vorgangs (Mandant +
  /// Zentralruf-Antwort + Vorgangsfelder) auf.
  static String? _ausDatenquelle(
    FeldDatenquelle quelle,
    Vorgang vorgang,
    Mandant? mandant,
  ) {
    final antwort = vorgang.antwort;
    switch (quelle) {
      case FeldDatenquelle.keine:
        return null;

      case FeldDatenquelle.mandantName:
        return mandant?.anzeigename ?? vorgang.mandantName;
      case FeldDatenquelle.mandantVorname:
        return mandant?.vorname;
      case FeldDatenquelle.mandantNachname:
        return mandant?.nachname;
      case FeldDatenquelle.mandantBriefanrede:
        return mandant?.briefanrede;
      case FeldDatenquelle.mandantStrasse:
        return mandant?.strasseHausnummer;
      case FeldDatenquelle.mandantPlz:
        return mandant?.postleitzahl;
      case FeldDatenquelle.mandantOrt:
        return mandant?.ort;
      case FeldDatenquelle.mandantAnschrift:
        return MandantAnschrift.aus(mandant);
      case FeldDatenquelle.mandantEmail:
        return mandant?.emailAdresse;
      case FeldDatenquelle.mandantTelefon:
        return mandant?.telefonnummer;

      case FeldDatenquelle.versichererName:
        return antwort?.versichererName;
      case FeldDatenquelle.versichererStrasse:
        return antwort?.versichererStrasse;
      case FeldDatenquelle.versichererPlz:
        return antwort?.versichererPlz;
      case FeldDatenquelle.versichererOrt:
        return antwort?.versichererOrt;
      case FeldDatenquelle.versichererAdresse:
        return antwort?.versichererAdresseOhneName;
      case FeldDatenquelle.versichererAnschrift:
        return antwort?.versichererAnschrift;
      case FeldDatenquelle.versichererEmail:
        return antwort?.versichererEmail;
      case FeldDatenquelle.versichererTelefon:
        return antwort?.versichererTelefon;
      case FeldDatenquelle.versichererFax:
        return antwort?.versichererFax;
      case FeldDatenquelle.versicherungsscheinNr:
        return antwort?.versicherungsscheinNr;
      case FeldDatenquelle.versicherungsbeginn:
        return antwort?.versicherungsbeginn;

      case FeldDatenquelle.kennzeichenGegner:
        return vorgang.kennzeichen ?? antwort?.kennzeichen;
      case FeldDatenquelle.kennzeichenMandant:
        return _mandantenKennzeichen(vorgang, mandant);
      case FeldDatenquelle.unfalldatum:
        return vorgang.unfallDatum ?? antwort?.unfallDatum;
      case FeldDatenquelle.unfallort:
        return vorgang.unfallort;
      case FeldDatenquelle.unfalluhrzeit:
        return vorgang.unfalluhrzeit;
      case FeldDatenquelle.polizeiVorgangsnummer:
        return vorgang.polizeiVorgangsnummer;
      case FeldDatenquelle.referenz:
        return vorgang.referenz.isNotEmpty
            ? vorgang.referenz
            : antwort?.referenz;
      case FeldDatenquelle.zeichen:
        return vorgang.zeichen;
      case FeldDatenquelle.rechtsgebiet:
        return vorgang.rechtsgebietAnzeige;
    }
  }

  /// Das eigene Fahrzeug des Mandanten (§4.4): erst der Vorgang, dann — und nur
  /// bei **genau einem** Eintrag — das Mandantenregister (§5.1).
  ///
  /// Mehrere Kennzeichen im Register sind eine *Auswahl* und keine Vorbelegung:
  /// Ein Mandant kann mehrere Fahrzeuge halten, und welches in diesem Unfall
  /// beschädigt wurde, weiß das Register nicht. Eines davon zu nehmen wäre in
  /// jedem zweiten Fall das falsche und stünde ungeprüft im Anspruchsschreiben
  /// — deshalb bleibt das Feld leer und der Anwalt wählt über die Auswahlhilfe
  /// am Feld (`DatenquelleVorschlaege`, §1.3 „vorschlagen statt entscheiden").
  ///
  /// Das Kennzeichen des **Gegners** kommt hier unter keinen Umständen herein;
  /// das war die Regression, für die es früher die Notbremse „bleibt lieber
  /// leer" gab.
  static String? _mandantenKennzeichen(Vorgang vorgang, Mandant? mandant) {
    final eigenes = vorgang.geschaedigtenKennzeichen?.trim();
    if (eigenes != null && eigenes.isNotEmpty) return eigenes;

    final ausRegister = _registerKennzeichen(mandant);
    return ausRegister.length == 1 ? ausRegister.single : null;
  }

  /// Die nicht-leeren Kennzeichen des Registereintrags, gestutzt.
  static List<String> _registerKennzeichen(Mandant? mandant) => [
    for (final wert in mandant?.kennzeichen ?? const <String>[])
      if (wert.trim().isNotEmpty) wert.trim(),
  ];

  /// Herkunft eines über die [FeldDatenquelle] aufgelösten Werts. Bei Quellen
  /// mit Fallback (Name-Schnappschuss, Kennzeichen/Unfalldatum aus der
  /// Antwort) entscheidet der tatsächlich verwendete Datenbestand.
  static PrefillQuelle _quelleFuerDatenquelle(
    FeldDatenquelle quelle,
    Vorgang vorgang,
    Mandant? mandant,
  ) {
    switch (quelle) {
      case FeldDatenquelle.mandantName:
        return mandant != null ? PrefillQuelle.mandant : PrefillQuelle.vorgang;
      case FeldDatenquelle.kennzeichenGegner:
        return vorgang.kennzeichen != null
            ? PrefillQuelle.vorgang
            : PrefillQuelle.antwort;
      case FeldDatenquelle.kennzeichenMandant:
        // Gerufen wird das nur zu einem gefundenen Wert; kannte der Vorgang
        // das eigene Fahrzeug nicht, kam er also aus dem Register.
        return (vorgang.geschaedigtenKennzeichen?.trim() ?? '').isNotEmpty
            ? PrefillQuelle.vorgang
            : PrefillQuelle.mandant;
      case FeldDatenquelle.unfalldatum:
        return vorgang.unfallDatum != null
            ? PrefillQuelle.vorgang
            : PrefillQuelle.antwort;
      default:
        // Die übrigen Quellen sind eindeutig gruppiert (siehe FeldDatenquelle):
        // mandant* → Register, versicher* → Antwort, Rest → Vorgangsfelder.
        // Geprüft wird der stabile Persistenz-Schlüssel [FeldDatenquelle.value]
        // ([FeldDatenquelle.name] ist der Anzeigename).
        final schluessel = quelle.value;
        if (schluessel.startsWith('mandant')) return PrefillQuelle.mandant;
        if (schluessel.startsWith('versicher')) return PrefillQuelle.antwort;
        return PrefillQuelle.vorgang;
    }
  }
}
