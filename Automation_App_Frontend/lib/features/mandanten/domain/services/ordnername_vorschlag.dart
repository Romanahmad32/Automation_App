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
///
/// **Ein einzelnes Wort ist der Nachname**, nicht der Vorname: Die echten
/// Aktenordner der Kanzlei heißen `VUnfallursache <Nachname>` — an 61 von 61
/// Ordnern des eingestellten Stammordners belegt, ohne Vornamen und ohne
/// Komma. Landete das Wort im Vornamenfeld, suchte alles, was am Nachnamen
/// hängt, mit einer leeren Zeichenkette: `MandantenNamensindex.kandidaten`
/// fände nichts, `SichereTreffer` käme nie an einen Vergleich, und der
/// Dublettenhinweis im Arbeitspaket bliebe bei jedem echten Ordner leer.
///
/// Eine Komma-Heuristik für „Nachname, Vorname" steht **bewusst nicht**
/// daneben: Der Anwalt bestätigte, dass es sie nicht gibt — auch eine zweite
/// Auslegung derselben Präfixtabelle.
({String vorname, String nachname}) nameVorschlagAusOrdner(String ordnername) {
  final praefix = AktentypErkennung.erkenne(ordnername).praefix;
  final rest = ordnername.trim().substring(praefix.length).trim();
  if (rest.isEmpty) return (vorname: '', nachname: '');

  final teile = rest.split(RegExp(r'\s+'));
  if (teile.length == 1) return (vorname: '', nachname: teile.first);
  return (vorname: teile.first, nachname: teile.sublist(1).join(' '));
}
