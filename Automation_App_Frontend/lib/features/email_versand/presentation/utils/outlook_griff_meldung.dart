import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';

/// Sagt in einem Satz, was der Griff nach Outlook ergeben hat (§4.7).
///
/// Der Griff ist von aussen nicht zu sehen: Outlook liegt womöglich hinter der
/// App, und drei seiner vier Ausgänge sehen gleich aus — es rührt sich nichts.
/// Genau diese drei müssen gesagt werden. Nur der vierte, neue Vorschläge,
/// spricht für sich: Sie stehen dann in der Reihe.
///
/// Eigener Baustein, weil zwei Wege hierher führen: der Knopf „Aus der
/// Outlook-Nachricht" und das Ablegen eines Anhangs, den Windows nicht als
/// Datei durchreicht.
abstract final class OutlookGriffMeldung {
  /// Die Meldung, oder null, wenn der Griff für sich spricht.
  ///
  /// [neu] ist die Zahl der Vorschläge, die noch nicht in der Reihe lagen.
  static String? fuer(OutlookAnhaenge griff, int neu, {String? vorspann}) {
    final satz = _satz(griff, neu);
    if (satz == null) return null;
    return vorspann == null ? satz : '$vorspann $satz';
  }

  static String? _satz(OutlookAnhaenge griff, int neu) {
    if (!griff.outlookErreicht) {
      return 'Outlook hat nicht geantwortet. Läuft es, und ist die Nachricht '
          'dort geöffnet oder in der Liste markiert?';
    }
    if (!griff.hatNachricht) {
      return 'In Outlook ist keine Nachricht geöffnet oder in der Liste '
          'markiert.';
    }
    if (griff.pfade.isEmpty) {
      return 'An der Nachricht ${griff.bezeichnung} hängt keine Datei. '
          'Eingebettete Bilder aus der Signatur des Absenders zählen nicht mit.';
    }
    if (neu == 0) {
      return 'Die Anhänge von ${griff.bezeichnung} stehen bereits in der '
          'Auswahl.';
    }
    return null;
  }
}
