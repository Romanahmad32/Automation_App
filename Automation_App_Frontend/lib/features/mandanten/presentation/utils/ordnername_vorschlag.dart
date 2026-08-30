import 'package:automation_app/features/mandanten/domain/services/aktentyp_erkennung.dart';

/// Komfort-Heuristik für die manuelle Zuordnung: schlägt aus einem Akten-
/// Ordnernamen einen Mandantennamen vor, indem das Aktentyp-Präfix abgestreift
/// wird (z. B. „VUnfallursache Mark" → „Mark"). Nur ein Vorschlag — der Nutzer
/// bestätigt oder korrigiert ihn beim Anlegen.
///
/// Welche Präfixe es gibt, steht in [AktentypErkennung]: dieselbe Tabelle, nach
/// der die Zuordnungsliste filtert. Unbekannte Ordnernamen werden unverändert
/// zurückgegeben.
///
/// Liefert (vorname, nachname) — der Rest hinter dem Präfix wird am ersten
/// Leerzeichen geteilt.
({String vorname, String nachname}) nameVorschlagAusOrdner(String ordnername) {
  final praefix = AktentypErkennung.erkenne(ordnername).praefix;
  final rest = ordnername.trim().substring(praefix.length).trim();
  if (rest.isEmpty) return (vorname: '', nachname: '');

  final teile = rest.split(RegExp(r'\s+'));
  if (teile.length == 1) return (vorname: teile.first, nachname: '');
  return (vorname: teile.first, nachname: teile.sublist(1).join(' '));
}
