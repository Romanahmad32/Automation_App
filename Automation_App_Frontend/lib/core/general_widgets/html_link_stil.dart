import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:material_ui/material_ui.dart';

/// Die Linkfarbe für gerendertes HTML (Issue #185).
///
/// `flutter_widget_from_html_core` liest die Linkfarbe aus dem alten
/// Material-Theme des SDK. Das gibt es unter `material_ui` nicht mehr; ohne
/// Vorkehrung fiele die Farbe auf dessen Vorgabe (#6750A4, Lila) zurück. Dieser
/// Baustein gibt Verweisen (`<a href>`) stattdessen `colorScheme.primary` aus
/// dem material_ui-Theme — so folgen sie dem Farbschema, auch im dunklen Modus.
///
/// Eine Farbe, die das HTML selbst am Element trägt (`style="color: …"`, etwa
/// in einer Outlook-Signatur), bleibt unberührt: Sie ist Absicht des Absenders.
class HtmlLinkStil {
  const HtmlLinkStil._();

  /// Erkennt eine `color`-Angabe im `style`-Merkmal (nicht `background-color`).
  static final RegExp _eigeneFarbe = RegExp(
    r'(^|;)\s*color\s*:',
    caseSensitive: false,
  );

  /// Der `customStylesBuilder` für [farben]; verkettet mit [weiter], falls die
  /// Stelle schon einen eigenen hat. Dessen Angaben gewinnen: Sie werden nach
  /// der Linkfarbe eingesetzt und dürfen sie überschreiben.
  static CustomStylesBuilder fuer(
    ColorScheme farben, {
    CustomStylesBuilder? weiter,
  }) {
    final hex = hexVon(farben.primary);
    return (element) {
      final weitere = weiter?.call(element);
      // Wie fwfh selbst nur `a[href]`: Anker ohne Ziel (`<a name="…">`,
      // Outlook) sind keine Verweise und bleiben in der Textfarbe.
      if (element.localName != 'a' || !element.attributes.containsKey('href')) {
        return weitere;
      }
      final style = element.attributes['style'] ?? '';
      if (_eigeneFarbe.hasMatch(style)) return weitere;
      return {'color': hex, ...?weitere};
    };
  }

  /// `#RRGGBB` ohne Alphakanal.
  static String hexVon(Color farbe) =>
      '#${(farbe.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
