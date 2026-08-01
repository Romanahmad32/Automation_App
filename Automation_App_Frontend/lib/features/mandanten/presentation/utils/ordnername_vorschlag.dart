/// Komfort-Heuristik für die manuelle Zuordnung: schlägt aus einem Akten-
/// Ordnernamen einen Mandantennamen vor, indem ein bekanntes Aktentyp-Präfix
/// abgestreift wird (z. B. „VUnfallursache Mark" → „Mark"). Nur ein Vorschlag —
/// der Nutzer bestätigt/korrigiert ihn beim Anlegen.
///
/// Die Präfix-Liste deckt die in der Kanzlei beobachteten (uneinheitlichen)
/// Schreibweisen ab; unbekannte Ordnernamen werden unverändert zurückgegeben.
const List<String> bekannteAktentypPraefixe = [
  'VUnvallursache',
  'VUnfallursache',
  'VerkUnfursache',
  'Verkehrsunfallsache',
  'Bußgeldsache',
  'Bussgeldsache',
  'Strafsache',
  'StrSache',
  'BSsache',
  'FamSache',
  'Familiensache',
  'Owi',
];

/// Liefert (vorname, nachname) als Vorschlag aus einem Ordnernamen. Splittet den
/// Rest nach dem Präfix am ersten Leerzeichen in Vor- und Nachname.
({String vorname, String nachname}) nameVorschlagAusOrdner(String ordnername) {
  var rest = ordnername.trim();
  for (final praefix in bekannteAktentypPraefixe) {
    if (rest.toLowerCase().startsWith(praefix.toLowerCase())) {
      rest = rest.substring(praefix.length).trim();
      break;
    }
  }
  if (rest.isEmpty) return (vorname: '', nachname: '');

  final teile = rest.split(RegExp(r'\s+'));
  if (teile.length == 1) return (vorname: teile.first, nachname: '');
  return (vorname: teile.first, nachname: teile.sublist(1).join(' '));
}
