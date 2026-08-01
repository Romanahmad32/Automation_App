import 'package:automation_app/features/form_template_setup/domain/entities/feld_datenquelle.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/prefill_wert.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/mandant_feld_heuristik.dart';
import 'package:automation_app/features/zentralruf_reply/domain/services/vorgangsdaten_field_matcher.dart';

/// Ordnet die in einem [Vorgang] gebündelten Daten den frei benannten Feldern
/// einer Formularvorlage zu — die Phase-4-Erweiterung des
/// [VorgangsdatenFieldMatcher]:
///
/// * Mandant-/Geschädigten-/Kundenfelder kommen aus dem verknüpften [Mandant]
///   (bzw. dem Namens-Schnappschuss des Vorgangs, wenn kein Registereintrag
///   vorliegt),
/// * das Rechtsgebiet aus dem Vorgang,
/// * alle übrigen Felder (Versicherer, Unfalldatum, Referenz …) aus der
///   übernommenen Zentralruf-Antwort über die bewährte Antwort-Heuristik.
///
/// Felder ohne eindeutige Zuordnung bleiben leer — lieber unbefüllt als falsch
/// vorbelegt (Req. 3.4). Jeder Wert trägt seine Herkunft ([PrefillWert]) für
/// die Anzeige am Feld, damit der Anwalt falsche Vorbelegungen sofort erkennt.
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

  /// Liefert je Feld den vorzubelegenden Wert samt Herkunft. Felder mit
  /// explizit gewählter [FeldDatenquelle] werden direkt aufgelöst; Felder ohne
  /// feste Quelle ([FeldDatenquelle.keine]) laufen über die Namens-Heuristik
  /// ([matchFieldsMitHerkunft]), damit bestehende Vorlagen unverändert
  /// weiterlaufen.
  ///
  /// Wurde zum Vorgang schon einmal ein Dokument erzeugt, gewinnen die dabei
  /// bestätigten Werte ([Vorgang.feldWerte]) über beide Wege — der Anwalt hat
  /// sie bereits gesehen und abgesegnet (Rückfluss, siehe VorgangRueckfluss).
  static Map<String, PrefillWert> matchTemplateFieldsMitHerkunft(
    List<FieldData> fields,
    Vorgang vorgang, {
    Mandant? mandant,
  }) {
    final result = <String, PrefillWert>{};
    final heuristikLabels = <String>[];

    for (final field in fields) {
      if (!field.datenquelle.istGesetzt) {
        heuristikLabels.add(field.label);
        continue;
      }
      final wert = _ausDatenquelle(field.datenquelle, vorgang, mandant);
      if (wert != null && wert.isNotEmpty) {
        result[field.label] = PrefillWert(
          wert,
          _quelleFuerDatenquelle(field.datenquelle, vorgang, mandant),
        );
      }
    }

    // Ungebundene Felder über die bewährte Heuristik nachziehen. Explizit
    // gesetzte Felder gewinnen, falls ein Label zufällig beide Wege träfe.
    final ausHeuristik = matchFieldsMitHerkunft(
      heuristikLabels,
      vorgang,
      mandant: mandant,
    );
    for (final eintrag in ausHeuristik.entries) {
      result.putIfAbsent(eintrag.key, () => eintrag.value);
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

  /// Löst eine explizit gewählte [FeldDatenquelle] gegen die Daten des Vorgangs
  /// (Mandant + Zentralruf-Antwort + Vorgangsfelder) auf.
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
      case FeldDatenquelle.mandantStrasse:
        return mandant?.strasseHausnummer;
      case FeldDatenquelle.mandantPlz:
        return mandant?.postleitzahl;
      case FeldDatenquelle.mandantOrt:
        return mandant?.ort;
      case FeldDatenquelle.mandantAnschrift:
        return MandantFeldHeuristik.anschrift(mandant);
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
        return vorgang.geschaedigtenKennzeichen;
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
      case FeldDatenquelle.aktenzeichen:
        return vorgang.aktenzeichen;
      case FeldDatenquelle.rechtsgebiet:
        return vorgang.rechtsgebiet.displayName;
    }
  }

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

  /// Liefert je Feldname (Label) den vorzubelegenden Wert (ohne Herkunft).
  static Map<String, String> matchFields(
    Iterable<String> fieldLabels,
    Vorgang vorgang, {
    Mandant? mandant,
  }) {
    return matchFieldsMitHerkunft(
      fieldLabels,
      vorgang,
      mandant: mandant,
    ).map((label, wert) => MapEntry(label, wert.wert));
  }

  /// Namens-Heuristik mit Herkunft: Mandantenfelder aus dem Register
  /// ([MandantFeldHeuristik]), Rechtsgebiet aus dem Vorgang, alle übrigen
  /// Felder aus der Zentralruf-Antwort.
  static Map<String, PrefillWert> matchFieldsMitHerkunft(
    Iterable<String> fieldLabels,
    Vorgang vorgang, {
    Mandant? mandant,
  }) {
    final labels = fieldLabels.toList();

    // Versicherer-/Antwortfelder über die bewährte Antwort-Heuristik. Sie lässt
    // Mandant-/Geschädigtenfelder bewusst leer, sodass es hier keine Kollision
    // mit der Mandanten-Vorbelegung gibt.
    final antwort = vorgang.antwort;
    final ausAntwort = antwort == null
        ? const <String, String>{}
        : VorgangsdatenFieldMatcher.matchFields(labels, antwort);

    final result = <String, PrefillWert>{};
    for (final label in labels) {
      final normalized = MandantFeldHeuristik.normalize(label);

      final mandantWert = MandantFeldHeuristik.wertFuer(
        normalized,
        mandant,
        vorgang,
      );
      if (mandantWert != null && mandantWert.wert.isNotEmpty) {
        result[label] = mandantWert;
        continue;
      }

      if (normalized.contains('rechtsgebiet') ||
          normalized.contains('sachgebiet')) {
        result[label] = PrefillWert(
          vorgang.rechtsgebiet.displayName,
          PrefillQuelle.vorgang,
        );
        continue;
      }

      final antwortWert = ausAntwort[label];
      if (antwortWert != null && antwortWert.isNotEmpty) {
        result[label] = PrefillWert(antwortWert, PrefillQuelle.antwort);
      }
    }
    return result;
  }
}
