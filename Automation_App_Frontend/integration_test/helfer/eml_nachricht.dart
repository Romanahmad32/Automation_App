import 'dart:convert';
import 'dart:io';

/// Eine `.eml`, wie sie die Versand-Attrappe des Testmodus ablegt (#168):
/// genau die Nachricht, die im echten Betrieb an den SMTP-Server ginge.
///
/// Gelesen wird nur, was ein Durchlauf prüft — Empfänger, Betreff und die
/// Namen der Anhänge. Kein vollständiger MIME-Leser: Der Absender ist MimeKit,
/// dessen Kopfzeilen ASCII sind (Umlaute als RFC 2047 bzw. RFC 2231), und ein
/// Dateiname mit Semikolon kommt in den Durchläufen nicht vor.
class EmlNachricht {
  /// Die Kopfzeilen der Nachricht selbst (nicht der Teile), Name klein
  /// geschrieben, Folgezeilen zusammengezogen.
  final Map<String, String> kopf;

  /// Die Dateinamen aller Teile mit `Content-Disposition: attachment`.
  final List<String> anhaenge;

  const EmlNachricht({required this.kopf, required this.anhaenge});

  factory EmlNachricht.lies(File datei) {
    // latin1 wirft bei keinem Byte; alles Lesenswerte ist ohnehin ASCII.
    final zeilen = _entfalte(datei.readAsStringSync(encoding: latin1));
    final ende = zeilen.indexOf('');
    final kopf = <String, String>{};
    for (final zeile in ende < 0 ? zeilen : zeilen.take(ende)) {
      final trenner = zeile.indexOf(':');
      if (trenner <= 0) continue;
      kopf.putIfAbsent(
        zeile.substring(0, trenner).trim().toLowerCase(),
        () => zeile.substring(trenner + 1).trim(),
      );
    }
    final anhaenge = [
      for (final zeile in zeilen)
        if (zeile.toLowerCase().startsWith('content-disposition:') &&
            zeile.toLowerCase().contains('attachment'))
          ?_dateiname(zeile),
    ];
    return EmlNachricht(kopf: kopf, anhaenge: anhaenge);
  }

  List<String> get an => _adressen(kopf['to']);
  List<String> get kopie => _adressen(kopf['cc']);
  String get betreff => _dekodiere(kopf['subject'] ?? '');

  /// Folgezeilen (beginnen mit Leerraum) an die Kopfzeile davor hängen.
  static List<String> _entfalte(String text) {
    final ergebnis = <String>[];
    for (final zeile in const LineSplitter().convert(text)) {
      final folge = zeile.startsWith(' ') || zeile.startsWith('\t');
      if (folge && ergebnis.isNotEmpty && ergebnis.last.isNotEmpty) {
        ergebnis.last = '${ergebnis.last} ${zeile.trim()}';
      } else {
        ergebnis.add(zeile);
      }
    }
    return ergebnis;
  }

  static List<String> _adressen(String? kopfzeile) => [
    for (final treffer in RegExp(
      r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+',
    ).allMatches(kopfzeile ?? ''))
      treffer.group(0)!.toLowerCase(),
  ];

  /// `filename="…"`, `filename*=utf-8''…` und die Fortsetzungen
  /// `filename*0*=…; filename*1*=…` (RFC 2231).
  static String? _dateiname(String zeile) {
    final teile = <int, String>{};
    var kodiert = false;
    for (final parameter in zeile.split(';').skip(1)) {
      final gleich = parameter.indexOf('=');
      if (gleich < 0) continue;
      final name = parameter.substring(0, gleich).trim().toLowerCase();
      if (!name.startsWith('filename')) continue;
      var wert = parameter.substring(gleich + 1).trim();
      if (wert.startsWith('"') && wert.endsWith('"') && wert.length >= 2) {
        wert = wert.substring(1, wert.length - 1);
      }
      final nummer = RegExp(r'\*(\d+)').firstMatch(name)?.group(1);
      if (name.endsWith('*')) kodiert = true;
      teile[nummer == null ? 0 : int.parse(nummer)] = wert;
    }
    if (teile.isEmpty) return null;
    final schluessel = teile.keys.toList()..sort();
    var name = schluessel.map((nummer) => teile[nummer]).join();
    if (kodiert) {
      final apostroph = name.indexOf("''");
      if (apostroph >= 0) name = name.substring(apostroph + 2);
      name = Uri.decodeComponent(name);
    }
    return _dekodiere(name);
  }

  /// RFC-2047-Wörter (`=?utf-8?B?…?=` bzw. `?Q?`) in Klartext.
  static String _dekodiere(String text) => text.replaceAllMapped(
    RegExp(r'=\?([^?]+)\?([BbQq])\?([^?]*)\?='),
    (treffer) {
      final inhalt = treffer.group(3)!;
      final bytes = treffer.group(2)!.toUpperCase() == 'B'
          ? base64.decode(inhalt)
          : _quotedPrintable(inhalt);
      return utf8.decode(bytes, allowMalformed: true);
    },
  );

  static List<int> _quotedPrintable(String text) {
    final bytes = <int>[];
    for (var i = 0; i < text.length; i++) {
      final zeichen = text[i];
      if (zeichen == '=' && i + 2 < text.length) {
        bytes.add(int.parse(text.substring(i + 1, i + 3), radix: 16));
        i += 2;
      } else {
        bytes.add(zeichen == '_' ? 0x20 : zeichen.codeUnitAt(0));
      }
    }
    return bytes;
  }
}
