import 'package:automation_app/features/form_template_setup/domain/entities/field_data.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/vorgang_prefill_matcher.dart';

/// Der Eingabestand nach einer geänderten Feldeinstellung: beide Karten und
/// der Wert, der dabei der Vorbelegung gewichen ist (`null` = keiner, oder er
/// war leer und damit nichts, was man zurückholen möchte).
typedef GeaenderterFeldStand = ({
  Map<String, String>? formData,
  Map<String, String>? formDataEntwurf,
  String? verdraengterWert,
});

/// Was mit dem erfassten Eingabestand geschieht, wenn ein Vorlagenfeld im
/// Ausfüllschritt geändert wird.
///
/// Der Stand (`formData`, `formDataEntwurf`) ist nach **Feldnamen**
/// geschlüsselt — die Vorlage zu ändern heißt deshalb immer auch, an dieser
/// Karte etwas zu tun. Die Regeln liegen hier zusammen, weil sie leicht zu
/// verwechseln sind und beide still danebengehen: Das Formular zeigte dann
/// einfach einen anderen Wert als gedacht, ohne dass etwas anschlägt.
class FeldStand {
  const FeldStand._();

  /// Ob der erfasste Wert des Felds der Vorbelegung Platz machen soll.
  ///
  /// Zwei Bedingungen, und die zweite ist die wichtigere: Die neue Quelle muss
  /// zum gewählten Vorgang **tatsächlich einen Wert haben**. Sonst nähme der
  /// Dialog dem Anwalt seine Eingabe weg und setzte nichts an ihre Stelle — für
  /// ein leeres Feld lohnt kein Tausch. Gefragt wird derselbe Dienst, aus dem
  /// auch das Formular seine Vorbelegung zieht; was er hier verspricht, steht
  /// gleich darauf im Feld.
  static bool weichtDerVorbelegung(
    FieldData alt,
    FieldData neu, {
    required Vorgang? vorgang,
    required Mandant? mandant,
  }) {
    if (vorgang == null || alt.datenquelle == neu.datenquelle) return false;
    return VorgangPrefillMatcher.matchTemplateFields(
      [neu],
      vorgang,
      mandant: mandant,
    ).containsKey(neu.label);
  }

  /// Beide Karten nach der Änderung — und der verdrängte Wert für die Meldung.
  ///
  /// [weicht] entscheidet zwischen den zwei Fällen:
  ///
  /// **Neue Datenquelle** (`true`): Der Wert gibt im Entwurf den Platz frei,
  /// damit die Vorbelegung greift. Ohne das gibt es keinen Weg zurück zu ihr —
  /// der `FormWertBeobachter` schreibt zwei Sekunden nach dem ersten
  /// Tastendruck *alle* Felder mit, auch die unangetasteten, und ab da
  /// beschattet der erfasste Stand die Vorbelegung dauerhaft.
  ///
  /// **Alles andere** (`false`, also Umbenennung, Typ, Pflichthaken): Der Wert
  /// wandert auf den neuen Namen mit, sonst fände er sich nur unter einem, den
  /// die Vorlage nicht mehr kennt.
  ///
  /// [formData] wird **nie** geräumt, nur umgeschlüsselt: Es ist der
  /// abgesendete Stand, aus dem erzeugt wird. Ein Loch darin hinterließe einen
  /// unersetzten `{{Platzhalter}}` in einem Schreiben, das hinausgeht.
  static GeaenderterFeldStand nachAenderung({
    required Map<String, String>? formData,
    required Map<String, String>? formDataEntwurf,
    required FieldData alt,
    required FieldData neu,
    required bool weicht,
  }) {
    final alterWert = formDataEntwurf?[alt.label];
    // Ein leerer Wert ist nichts, was man zurückholen möchte — die Meldung
    // böte einen Knopf an, der das Feld wieder leert.
    final zurueckholbar =
        weicht && alterWert != null && alterWert.trim().isNotEmpty;
    return (
      formData: umgeschluesselt(formData, alt, neu),
      formDataEntwurf: weicht
          ? ohneFeld(formDataEntwurf, alt)
          : umgeschluesselt(formDataEntwurf, alt, neu),
      verdraengterWert: zurueckholbar ? alterWert : null,
    );
  }

  /// Trägt den Wert von [alt] auf den Namen von [neu] um.
  ///
  /// Ein **leerer** Wert fällt weg, statt mitzugehen: Er hat nichts zu
  /// bewahren, schlüge aber die Vorbelegung.
  static Map<String, String>? umgeschluesselt(
    Map<String, String>? stand,
    FieldData alt,
    FieldData neu,
  ) {
    if (stand == null) return null;
    final wert = stand[alt.label];
    final umgetragen = Map<String, String>.of(stand)..remove(alt.label);
    if (wert != null && wert.trim().isNotEmpty) umgetragen[neu.label] = wert;
    return umgetragen;
  }

  /// Nimmt das Feld ganz aus dem Stand. Anders als [umgeschluesselt]: Dort
  /// wandert der Wert mit, hier gibt er den Platz frei.
  static Map<String, String>? ohneFeld(
    Map<String, String>? stand,
    FieldData feld,
  ) {
    if (stand == null) return null;
    return Map<String, String>.of(stand)..remove(feld.label);
  }
}
