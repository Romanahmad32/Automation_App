import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';

/// Was beim Speichern mit dem Mandanten geschehen würde (§1.3): nichts, einen
/// neuen Mandanten anlegen oder den gewählten aktualisieren.
enum MandantAenderungsart { keine, neu, aktualisierung }

/// Eine Zeile der Mandanten-Übersicht: bei der Anlage nur [neu]; bei der
/// Aktualisierung der bisherige Wert [alt] und der neue Wert [neu].
class MandantFeldDiff {
  final String label;
  final String alt;
  final String neu;

  const MandantFeldDiff({
    required this.label,
    this.alt = '',
    required this.neu,
  });
}

/// Bestimmt, ob aus den Eingaben ein neuer Mandant entstünde, ein bestehender
/// geändert würde oder nichts zu tun ist. Grundlage für Button-Zustand/-Label
/// und für die Rückfrage beim „Vorgang speichern".
MandantAenderungsart mandantAenderungsart(
  VorgangStartenDaten daten,
  Mandant? gewaehlt,
) {
  if (gewaehlt == null) {
    return daten.hatMandantDaten
        ? MandantAenderungsart.neu
        : MandantAenderungsart.keine;
  }
  return daten.weichtAbVon(gewaehlt)
      ? MandantAenderungsart.aktualisierung
      : MandantAenderungsart.keine;
}

/// Die ausgefüllten Felder für einen neu anzulegenden Mandanten (leere weggelassen).
List<MandantFeldDiff> mandantNeuFelder(VorgangStartenDaten daten) {
  final felder = <MandantFeldDiff>[];
  void fuegeHinzu(String label, String wert) {
    final w = wert.trim();
    if (w.isNotEmpty) felder.add(MandantFeldDiff(label: label, neu: w));
  }

  fuegeHinzu('Name', daten.mandantName);
  fuegeHinzu('Straße und Hausnummer', daten.strasseHausnummer);
  fuegeHinzu('PLZ', daten.postleitzahl);
  fuegeHinzu('Ort', daten.ort);
  fuegeHinzu('E-Mail', daten.emailAdresse);
  fuegeHinzu('Telefon', daten.telefonnummer);
  fuegeHinzu('Kfz-Kennzeichen', daten.mandantKennzeichen);
  return felder;
}

/// Die gegenüber dem gespeicherten Mandanten geänderten Felder (alt → neu). Ein
/// neues, noch nicht hinterlegtes Kennzeichen erscheint als eigene Zeile.
List<MandantFeldDiff> mandantDiff(VorgangStartenDaten daten, Mandant m) {
  final diffs = <MandantFeldDiff>[];
  void vergleiche(String label, String alt, String neu) {
    if (alt.trim() != neu.trim()) {
      diffs.add(
        MandantFeldDiff(label: label, alt: alt.trim(), neu: neu.trim()),
      );
    }
  }

  vergleiche('Name', m.anzeigename, daten.mandantName);
  vergleiche(
    'Straße und Hausnummer',
    m.strasseHausnummer,
    daten.strasseHausnummer,
  );
  vergleiche('PLZ', m.postleitzahl, daten.postleitzahl);
  vergleiche('Ort', m.ort, daten.ort);
  vergleiche('E-Mail', m.emailAdresse, daten.emailAdresse);
  vergleiche('Telefon', m.telefonnummer, daten.telefonnummer);

  final neuesKennzeichen = daten.mandantKennzeichen.trim();
  final schonHinterlegt = m.kennzeichen.any(
    (k) => k.trim().toUpperCase() == neuesKennzeichen.toUpperCase(),
  );
  if (neuesKennzeichen.isNotEmpty && !schonHinterlegt) {
    diffs.add(
      MandantFeldDiff(label: 'Kfz-Kennzeichen (neu)', neu: neuesKennzeichen),
    );
  }
  return diffs;
}
