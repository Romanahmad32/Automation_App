import 'package:automation_app/features/email_versand/domain/entities/signatur_bild.dart';
import 'package:automation_app/features/email_versand/presentation/utils/signatur_bild_quelle.dart';

/// Macht Outlooks Signatur-HTML für die Vorschau anzeigbar (§4.7).
///
/// Zwei Dinge stehen dem im Weg. Erstens verweisen die Bilder auf ihren blanken
/// Dateinamen (`src="image001.png"`) — beim Versand wird daraus eine
/// Content-Id, in der Vorschau muss daraus die Adresse werden, unter der der
/// Dienst das Bild ausliefert. Zweitens steht im HTML weiterhin jedes Bild, das
/// der Anwalt für **diese** Mail abgewählt hat; sichtbar bliebe es sonst in
/// einer Vorschau, die behauptet, sie zeige, was hinausgeht.
///
/// Die verbindliche Entfernung macht der Dienst (`SignaturHtmlFilter`, der auch
/// die VML-Fassung erwischt). Hier geht es nur um die Anzeige — was der
/// Renderer ohnehin ignoriert, muss auch nicht fallen.
abstract final class SignaturHtmlAufbereitung {
  /// [weggelassen] sind die Dateinamen, die bei dieser Mail nicht mitgehen.
  ///
  /// [bilder] liefert je Dateiname seine Marke; sie gehört an die Adresse,
  /// sonst zeigt die Anzeige nach einem Signaturwechsel das alte Bild aus
  /// Flutters Bildspeicher ([SignaturBildQuelle]). [ausOutlook] ist gesetzt,
  /// solange die Signatur nur gelesen und noch nicht gespeichert ist — dann
  /// kommen die Bilder aus Outlooks Beiordner statt aus der Ablage.
  static String fuerAnzeige(
    String html, {
    List<String> weggelassen = const [],
    List<SignaturBild> bilder = const [],
    String ausOutlook = '',
  }) {
    if (html.trim().isEmpty) return '';

    final marken = {
      for (final bild in bilder) bild.dateiname.toLowerCase(): bild.marke,
    };
    final ohne = weggelassen.map((name) => name.toLowerCase()).toSet();
    final ohneAbgewaehlte = html.replaceAllMapped(_bildMarke, (treffer) {
      final quelle = _quelle.firstMatch(treffer[0]!);
      final name = quelle?.namedGroup('url') ?? '';
      return ohne.contains(name.toLowerCase()) ? '' : treffer[0]!;
    });

    return ohneAbgewaehlte.replaceAllMapped(_quelle, (treffer) {
      final regex = treffer as RegExpMatch;
      final name = regex.namedGroup('url') ?? '';
      // Verweise ins Netz und schon aufgelöste Adressen bleiben, wie sie sind.
      if (name.isEmpty || name.contains('://') || name.startsWith('data:')) {
        return treffer[0]!;
      }
      final quelle = SignaturBildQuelle.fuer(
        name,
        marke: marken[name.toLowerCase()] ?? '',
        ausOutlook: ausOutlook,
      );
      return '${regex.namedGroup('vor')}$quelle${regex.namedGroup('nach')}';
    });
  }

  static final RegExp _bildMarke = RegExp(
    r'<img\b[^>]*>',
    caseSensitive: false,
  );

  static final RegExp _quelle = RegExp(
    r'''(?<vor>\bsrc\s*=\s*(?<q>["']))(?<url>[^"']*)(?<nach>["'])''',
    caseSensitive: false,
  );
}
