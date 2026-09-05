/// Die drei wählbaren Schriftgrade der Oberfläche (Issue #57).
///
/// Bis hierher war der Schriftgrad eine Konstante im Theme: angehoben um zwei
/// Pixel, für jeden gleich. Was auf dem großen Monitor in der Kanzlei
/// angenehm ist, sprengt unterwegs die Spalten des Notebooks — und wem die
/// Anhebung nicht reicht, dem hilft sie nur halb. Die Stufe gehört deshalb dem
/// Anwalt und steht im Reiter „Darstellung" neben Design und Hell/Dunkel.
///
/// Drei benannte Stufen und kein stufenloser Regler: Ein Regler lädt zum
/// Probieren ein und trifft dabei Zwischenwerte, für die niemand das Layout
/// angesehen hat. Drei Stufen sind eine Entscheidung, keine Feinjustage.
///
/// **Hier stehen keine Pixel.** Wie viel eine Stufe zulegt, ist Sache der
/// Skala (`Schriftskala.zuschlag` in
/// `lib/core/theme/presentation/schriftskala.dart`): Die Domain kennt die
/// Wahl, nicht ihre Darstellung.
enum Schriftstufe {
  normal,
  groesser,
  amGroessten;

  /// Vorgabe für frische Installationen und für alles, was sich nicht lesen
  /// lässt. [groesser] ist der Stand, mit dem Issue #57 ausgeliefert wurde —
  /// wer nie etwas einstellt, sieht genau das, was er vorher sah.
  static const Schriftstufe vorgabe = Schriftstufe.groesser;

  /// Beschriftung im Reiter „Darstellung".
  String get bezeichnung => switch (this) {
    Schriftstufe.normal => 'Normal',
    Schriftstufe.groesser => 'Größer',
    Schriftstufe.amGroessten => 'Am größten',
  };

  /// Wert in `theme_preferences.json`. Bewusst der [name] und nicht der
  /// Index: Eine umsortierte Aufzählung verschöbe sonst still die bereits
  /// gespeicherte Wahl.
  String get jsonWert => name;

  /// Liest [wert] aus dem JSON zurück; `null` heißt „kenne ich nicht".
  ///
  /// Das ist der Normalfall und kein Fehler: eine `theme_preferences.json`
  /// aus der Zeit vor dieser Einstellung hat den Schlüssel gar nicht, eine
  /// von Hand bearbeitete kann jeden Unsinn enthalten. Was daraus wird,
  /// entscheidet der Aufrufer — `ThemePreferences.fromJson` nimmt die
  /// [vorgabe].
  static Schriftstufe? ausJson(Object? wert) {
    for (final stufe in Schriftstufe.values) {
      if (stufe.jsonWert == wert) return stufe;
    }
    return null;
  }
}
