/// Zieht die Empfängerliste einem gewechselten Vorgang nach (§4.7).
///
/// Der Fall, für den es diese Klasse gibt: Im Versanddialog ist der Vorgang
/// wählbar, und beim Wechsel stimmen die vorbelegten Adressen nicht mehr —
/// Mandant und Versicherung des **alten** Vorgangs standen im Feld „An".
/// Sie einfach alle zu ersetzen wäre falsch: Im Postfach trägt der Anwalt
/// regelmäßig zuerst eine Adresse von Hand ein und ordnet den Vorgang danach
/// zu. Sie wortlos zu löschen wäre der schlimmere Fehler von beiden — eine
/// überflüssige Adresse sieht er, eine verschwundene nicht.
class EmpfaengerAbgleich {
  const EmpfaengerAbgleich._();

  /// Die neue Liste: **Vorschläge des neuen Vorgangs zuerst**, dahinter alles,
  /// was der Anwalt selbst eingetragen hat. Was die App zum alten Vorgang
  /// **vorbelegt** hatte, geht mit ihm.
  ///
  /// [zuvorVorbelegt] sind genau diese Adressen — und nicht die Vorschläge des
  /// alten Vorgangs (geändert am 02.09.2026). Der Unterschied ist der Fall aus
  /// dem Postfach: Tippt der Anwalt die Mandantenadresse selbst ein und ordnet
  /// den Vorgang danach zu, steht dieselbe Adresse auch in dessen Vorschlägen.
  /// Über die Vorschlagsliste verglichen, verschwand sie beim nächsten Wechsel
  /// wortlos — der Fehler, den diese Klasse verhindern soll. Wer umgekehrt
  /// einen Vorschlag selbst angeklickt hat, behält ihn: eine überflüssige
  /// Adresse sieht er, eine verschwundene nicht.
  ///
  /// Zurück kommt **beides**: die Liste und die Adressen darin, die die App
  /// vorbelegt hat. Das zweite ist die Antwort auf denselben Fall beim
  /// *nächsten* Wechsel — eine selbst getippte Adresse bleibt selbst getippt,
  /// auch wenn der neue Vorgang sie ebenfalls vorschlägt. Sie stillschweigend
  /// zur Vorbelegung zu zählen hiesse, sie beim nächsten Wechsel doch noch zu
  /// verlieren.
  ///
  /// Verglichen wird ohne Rücksicht auf Groß- und Kleinschreibung und
  /// umschließende Leerzeichen — so wie Mailadressen gleich sind.
  static ({List<String> empfaenger, List<String> vorbelegt}) nachWechsel({
    required List<String> vorhanden,
    required List<String> zuvorVorbelegt,
    required List<String> neueVorschlaege,
  }) {
    final abgelegt = zuvorVorbelegt.map(_schluessel).toSet();
    final aufgenommen = <String>{};
    final ergebnis = <String>[];

    // Was dasteht und **nicht** aus der alten Vorbelegung stammt, hat der
    // Anwalt selbst eingetragen.
    final selbst = {
      for (final adresse in vorhanden)
        if (!abgelegt.contains(_schluessel(adresse))) _schluessel(adresse),
    };

    void nimm(String adresse) {
      final schluessel = _schluessel(adresse);
      if (schluessel.isEmpty) return;
      if (!aufgenommen.add(schluessel)) return;
      ergebnis.add(adresse.trim());
    }

    for (final adresse in neueVorschlaege) {
      nimm(adresse);
    }
    for (final adresse in vorhanden) {
      if (abgelegt.contains(_schluessel(adresse))) continue;
      nimm(adresse);
    }

    return (
      empfaenger: ergebnis,
      vorbelegt: [
        for (final adresse in neueVorschlaege)
          if (_schluessel(adresse).isNotEmpty &&
              !selbst.contains(_schluessel(adresse)))
            adresse.trim(),
      ],
    );
  }

  static String _schluessel(String adresse) => adresse.trim().toLowerCase();
}
