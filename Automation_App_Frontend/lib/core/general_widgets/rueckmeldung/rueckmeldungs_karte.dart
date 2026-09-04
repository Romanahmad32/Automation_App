import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldungs_inhalt.dart';
import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:flutter/material.dart';

/// Die sichtbare Karte **einer** Rückmeldung: Symbol, Text und Schließen-Knopf
/// in einer Zeile, darunter bei Bedarf der Aktionsknopf.
///
/// Optik: Rand, Radius 12 und ein sehr weicher, diffuser Schatten (keine harte
/// Material-Elevation) — mit dem Anwender abgestimmt (04.09.2026): Die Karte
/// schwebt im Wurzel-Overlay über allen Routen und ist deshalb die einzige
/// Fläche der App mit Schatten, sonst gilt überall Rand statt Schatten, weil
/// die App flach ist. Die Farben kommen über [SoftTone] aus der Akzentfarbe der
/// Art — nicht aus den `*Container`-Rollen, die das Theme im Light-Mode mit
/// nahezu schwarzen Markenfarben belegt (siehe Kopfkommentar von [SoftTone]).
/// Auch die Fehlerkarte bleibt damit ein getönter Kasten und kein roter Block.
///
/// Eingeblendet wird nur verblassend (200 ms). Beim Schließen verschwindet die
/// Karte sofort: Eine Karte, die noch 200 ms nachhängt, müsste im Stapel
/// weitergeführt werden, obwohl sie fachlich schon weg ist — das kostet mehr,
/// als das Ausblenden wert ist (04.09.2026, Issue #56).
class RueckmeldungsKarte extends StatefulWidget {
  const RueckmeldungsKarte({
    super.key,
    required this.inhalt,
    required this.beimSchliessen,
  });

  final RueckmeldungsInhalt inhalt;

  /// Aufgerufen vom Schließen-Knopf und vom Aktionsknopf.
  final VoidCallback beimSchliessen;

  @override
  State<RueckmeldungsKarte> createState() => _RueckmeldungsKarteState();
}

class _RueckmeldungsKarteState extends State<RueckmeldungsKarte>
    with SingleTickerProviderStateMixin {
  late final AnimationController _einblenden;

  late final Animation<double> _deckkraft = _einblenden.drive(
    CurveTween(curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _einblenden = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _einblenden.forward();
  }

  @override
  void dispose() {
    _einblenden.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ton = SoftTone.fromAccent(
      widget.inhalt.art.akzent(theme.colorScheme),
      theme.colorScheme,
    );
    final aktion = widget.inhalt.aktion;

    return FadeTransition(
      opacity: _deckkraft,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: ton.background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: ton.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _kopfzeile(theme, ton),
                if (aktion != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // Erst schließen, dann handeln: Die Handlung darf
                        // selbst eine neue Meldung zeigen, ohne die eigene zu
                        // treffen.
                        widget.beimSchliessen();
                        aktion.beiDruck();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: ton.foreground,
                      ),
                      child: Text(aktion.text),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kopfzeile(ThemeData theme, SoftTone ton) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Icon(widget.inhalt.art.icon, size: 20, color: ton.foreground),
        Expanded(
          child: Padding(
            // Hebt den Text auf die Höhe des Symbols, das der Knopf rechts
            // sonst überragt.
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              widget.inhalt.text,
              // Kein maxLines: Fehlermeldungen sagen, was zu tun ist — ein
              // abgeschnittener Satz sagt es nicht.
              softWrap: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ton.foreground,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: widget.beimSchliessen,
          icon: const Icon(Icons.close, size: 18),
          color: ton.foreground,
          tooltip: 'Schließen',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        ),
      ],
    );
  }
}
