import 'package:automation_app/features/mandanten/domain/services/aktentyp_erkennung.dart';

/// Komfort-Heuristik für die manuelle Zuordnung: schlägt aus einem Akten-
/// Ordnernamen einen Mandantennamen vor, indem das Aktentyp-Präfix abgestreift
/// wird (z. B. „VUnfallursache Schmidt" → Nachname „Schmidt"). Nur ein
/// Vorschlag — der Nutzer bestätigt oder korrigiert ihn beim Anlegen.
///
/// Welche Präfixe es gibt, steht in [AktentypErkennung]: dieselbe Tabelle, nach
/// der die Zuordnungsliste filtert. Unbekannte Ordnernamen werden unverändert
/// zurückgegeben.
///
/// Liefert (vorname, nachname) nach der Benennungskonvention dieser Kanzlei:
/// Der Rest hinter dem Präfix ist „Vorname Nachname" und wird am ersten
/// Leerzeichen geteilt; **steht dort nur ein Wort, ist es der Nachname**. So
/// benennt die Kanzlei ihre Akten — `docs/MANDANTEN_IMPORT.md` führt „Mark
/// Schmidt" mit den Ordnern „VUnfallursache Schmidt" und „Bußgeldsache
/// Schmidt". Ein einzelnes Wort als Vornamen zu lesen fände im Register nie
/// einen Treffer: `MandantErkennung` erkennt am Nachnamen wieder, der Vorname
/// verfeinert nur.
({String vorname, String nachname}) nameVorschlagAusOrdner(String ordnername) {
  final praefix = AktentypErkennung.erkenne(ordnername).praefix;
  final rest = ordnername.trim().substring(praefix.length).trim();
  if (rest.isEmpty) return (vorname: '', nachname: '');

  final teile = rest.split(RegExp(r'\s+'));
  if (teile.length == 1) return (vorname: '', nachname: teile.first);
  return (vorname: teile.first, nachname: teile.sublist(1).join(' '));
}
