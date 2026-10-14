import 'package:material_ui/material_ui.dart';

/// Eine Schrittfolge in einer Zeile — „① Herunterladen ② Neu starten ③ Fertig“
/// im Dialog „App aktualisieren“ (#196).
///
/// Sie steht in jedem Zustand an derselben Stelle, damit sichtbar bleibt, wo
/// man gerade ist: erledigte Schritte mit Haken (Ton der Primärfarbe), der
/// laufende gefüllt und fett, die übrigen nur umrandet. Vor dem Start und
/// nach einem Fehler läuft keiner ([aktiv] ist `null`).
///
/// Reicht die Breite nicht für eine Zeile mit Verbindern (große Schriftstufe,
/// schmales Fenster), brechen die Schritte um — ohne Verbinder, die sonst am
/// Zeilenende hingen. Kleiner wird die Schrift dafür nicht.
class SchrittAnzeige extends StatelessWidget {
  const SchrittAnzeige({
    required this.schritte,
    this.erledigt = 0,
    this.aktiv,
    super.key,
  });

  /// Die Beschriftungen, in Reihenfolge.
  final List<String> schritte;

  /// Wie viele Schritte von vorn erledigt sind.
  final int erledigt;

  /// Der laufende Schritt (ab 0), oder `null`.
  final int? aktiv;

  static const double _punkt = 24;
  static const double _luecke = 6;

  /// Ein Verbinder ist mindestens so lang, plus 8 px Abstand je Seite.
  static const double _verbinderMindestens = 12;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Ablauf',
      child: LayoutBuilder(
        builder: (context, platz) => _breite(context) <= platz.maxWidth
            ? Row(
                children: [
                  for (var stelle = 0; stelle < schritte.length; stelle++) ...[
                    _schritt(context, stelle),
                    if (stelle < schritte.length - 1)
                      Expanded(child: _verbinder(context, stelle)),
                  ],
                ],
              )
            : Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  for (var stelle = 0; stelle < schritte.length; stelle++)
                    _schritt(context, stelle),
                ],
              ),
      ),
    );
  }

  /// Was eine Zeile mit kürzesten Verbindern braucht — gemessen mit der
  /// Schrift, in der die Beschriftungen tatsächlich stehen.
  double _breite(BuildContext context) {
    final skalierung = MediaQuery.textScalerOf(context);
    final richtung = Directionality.of(context);
    var summe = (schritte.length - 1) * (_verbinderMindestens + 16);
    for (var stelle = 0; stelle < schritte.length; stelle++) {
      final maler = TextPainter(
        text: TextSpan(text: schritte[stelle], style: _stil(context, stelle)),
        textDirection: richtung,
        textScaler: skalierung,
        maxLines: 1,
      )..layout();
      summe += _punkt + _luecke + maler.width;
      maler.dispose();
    }
    return summe;
  }

  TextStyle _stil(BuildContext context, int stelle) {
    final theme = Theme.of(context);
    final laeuft = stelle == aktiv;
    return DefaultTextStyle.of(context).style.merge(
      theme.textTheme.labelMedium?.copyWith(
        color: laeuft
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: laeuft ? FontWeight.w600 : null,
      ),
    );
  }

  Widget _schritt(BuildContext context, int stelle) {
    final laeuft = stelle == aktiv;
    final fertig = stelle < erledigt && !laeuft;
    return Semantics(
      selected: laeuft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _kreis(context, stelle, laeuft: laeuft, fertig: fertig),
          const SizedBox(width: _luecke),
          Text(schritte[stelle], style: _stil(context, stelle)),
        ],
      ),
    );
  }

  Widget _kreis(
    BuildContext context,
    int stelle, {
    required bool laeuft,
    required bool fertig,
  }) {
    final theme = Theme.of(context);
    final schema = theme.colorScheme;
    final fuellung = laeuft
        ? schema.primary
        : fertig
        ? schema.primary.withValues(alpha: 0.15)
        : null;
    final rand = laeuft || fertig
        ? null
        : Border.all(color: schema.outline, width: 1.5);
    return SizedBox.square(
      dimension: _punkt,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fuellung,
          shape: BoxShape.circle,
          border: rand,
        ),
        child: Center(
          child: fertig
              ? Icon(Icons.check, size: 16, color: schema.primary)
              : Text(
                  '${stelle + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: laeuft ? schema.onPrimary : schema.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _verbinder(BuildContext context, int stelle) {
    final schema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 1,
        child: ColoredBox(
          color: stelle < erledigt
              ? schema.primary.withValues(alpha: 0.5)
              : schema.outlineVariant,
        ),
      ),
    );
  }
}
