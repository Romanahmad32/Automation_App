import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Der Dateiname des erzeugten Schreibens nach der Kanzlei-Konvention (§4.9):
///
/// ```
/// Anspruchsschreiben an {Versicherung} {Nr} {Vorlagenname}
/// Anspruchsschreiben an Allianz 1 Vorfahrtverletzung STOP 205
/// ```
///
/// Der Name beantwortet damit *an wen, das wievielte, worum*. Was er
/// **nicht** trägt, steht schon im Ablagepfad: das Unfalldatum im Ordnernamen
/// des Falls (§6.1) und der Mandant in der Akte darüber. Das Zeichen fehlt
/// ebenfalls — dort führt bereits der Pfad zum Vorgang (§4.2).
///
/// Die laufende Nummer ist nötig, weil alle Schreiben eines Vorgangs im
/// **selben** Unterordner landen (§4.9). Ohne sie träfe ein zweites Schreiben
/// derselben Vorlage auf den Namen des ersten, und die Ablage fragte jedes Mal
/// nach (`AblageStrategie`) statt beide nebeneinander zu legen.

/// Wortlaut vor dem Empfänger. Steht hier als Konstante, weil ihn die
/// Folgekorrespondenz (§4.9, Mahnung/Erinnerung) einmal ablösen wird: Solange
/// es nur Anspruchsschreiben gibt, ist er richtig — für eine Mahnung wird er
/// es nicht sein.
const String schreibenPraefix = 'Anspruchsschreiben';

/// Baut den Dateinamen ohne Endung. [nummer] ist die laufende Nummer des
/// Schreibens im Vorgang (das erste hat 1).
///
/// Fehlt der [versicherer] — ein Vorgang ohne Zentralruf-Antwort —, fällt das
/// „an" mit weg statt eine Lücke zu hinterlassen: „Anspruchsschreiben  1 …"
/// mit doppeltem Leerzeichen sieht aus wie ein Fehler und ist einer.
String schreibenDateiname({
  required String vorlagenname,
  required int nummer,
  String? versicherer,
}) {
  final empfaenger = (versicherer ?? '').trim();
  final vorlage = vorlagenname.trim();
  final teile = <String>[
    schreibenPraefix,
    if (empfaenger.isNotEmpty) 'an $empfaenger',
    '$nummer',
    if (vorlage.isNotEmpty) vorlage,
  ];
  return teile.join(' ');
}

/// Der Empfänger für den Dateinamen: die Versicherung aus der
/// Zentralruf-Antwort, sonst der eingetragene Gegner.
///
/// Diese Reihenfolge ist **umgekehrt** zu [Vorgang.parteienBezeichnung], und
/// das mit Absicht: Dort geht es um die Registerzeile „Mandant ./. Gegner", in
/// der die Eintragung des Anwalts gilt. Hier steht, an wen der Brief geht — und
/// das ist die Versicherung. Der Gegner bleibt der Rückfall, weil er bei
/// übernommener Antwort ohnehin meist ihr Name ist ([Vorgang.mitAntwort]), er
/// aber auch die Person am Steuer sein kann.
String? empfaengerFuerDateiname(Vorgang? vorgang) {
  final ausAntwort = (vorgang?.antwort?.versichererName ?? '').trim();
  if (ausAntwort.isNotEmpty) return ausAntwort;
  final eingetragen = (vorgang?.gegner ?? '').trim();
  return eingetragen.isEmpty ? null : eingetragen;
}

/// Die Nummer, die das **nächste** Schreiben zum Vorgang trägt.
///
/// [neuesSchreiben] ist die Entscheidung des Anwalts (§4.9): Eine Korrektur
/// behält die Nummer des vorigen und ersetzt damit dessen Fassung; ein neues
/// Schreiben bekommt die nächste. Geraten wird das nicht — beim ersten
/// Schreiben eines Vorgangs gibt es nichts zu entscheiden, dort ist es die 1.
int naechsteSchreibenNummer(Vorgang? vorgang, {required bool neuesSchreiben}) {
  final bisher = vorgang?.schreibenNummer;
  if (bisher == null || bisher < 1) return 1;
  return neuesSchreiben ? bisher + 1 : bisher;
}
