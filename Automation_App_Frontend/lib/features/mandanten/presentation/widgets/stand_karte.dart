import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_paket.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/paket_historie_tabelle.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/stand_verhaeltnisband.dart';
import 'package:flutter/material.dart';

/// Stand-Karte über der Filterleiste des Zuordnungsstapels (Issue #108):
/// Kopf, Zählerband, Verhältnisband und darunter — einklappbar — die
/// Paket-Historie.
///
/// Zustandsbehaftet nur wegen der zugeklappten Zeile: „zuletzt geholt am …"
/// steht **nur** dort, nicht mehr, sobald die Historie aufgeklappt ist.
class StandKarte extends StatefulWidget {
  /// Alle im Stammordner gescannten Ordner.
  final int gesamt;

  /// Davon bereits einem Mandanten zugeordnet.
  final int zugeordnet;

  /// Davon als „ohne Mandantenbezug" vermerkt.
  final int ohneBezug;

  /// Weder zugeordnet noch vermerkt — der Arbeitsvorrat.
  final int offen;

  /// Die Paket-Historie, neueste Nummer zuerst.
  final List<ImportPaket> pakete;

  /// Nimmt ein offenes Paket zurück — durchgereicht an [PaketHistorieTabelle].
  final void Function(int nummer) onPaketLoeschen;

  const StandKarte({
    super.key,
    required this.gesamt,
    required this.zugeordnet,
    required this.ohneBezug,
    required this.offen,
    required this.pakete,
    required this.onPaketLoeschen,
  });

  @override
  State<StandKarte> createState() => _StandKarteState();
}

class _StandKarteState extends State<StandKarte> {
  bool _aufgeklappt = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final letztesPaket = widget.pakete.isEmpty ? null : widget.pakete.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            spacing: 10,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.fact_check_outlined,
                  size: 19,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              Text('Stand der Übernahme', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _zaehlerChip(theme, '${widget.gesamt}', 'gesamt'),
              _zaehlerChip(theme, '${widget.zugeordnet}', 'zugeordnet'),
              _zaehlerChip(theme, '${widget.ohneBezug}', 'ohne Bezug'),
              _zaehlerChip(theme, '${widget.offen}', 'offen', betont: true),
            ],
          ),
          const SizedBox(height: 12),
          StandVerhaeltnisband(
            gesamt: widget.gesamt,
            zugeordnet: widget.zugeordnet,
            ohneBezug: widget.ohneBezug,
          ),
          const Divider(height: 25),
          // Durchsichtiges `Material` unter der farbigen Karte: Die Kopfzeile
          // des `ExpansionTile` ist ein `ListTile` und zeichnet ihren
          // Tipp-Kringel auf das nächste `Material` darüber — das läge hier
          // hinter der Kartenfarbe und bliebe unsichtbar. Seit Flutter 3.47
          // ist das eine Zusicherung (siehe ZuordnungAblaufHinweis, gleiche
          // Stelle, gleicher Grund).
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              onExpansionChanged: (wert) => setState(() => _aufgeklappt = wert),
              title: Row(
                children: [
                  Text(
                    'Pakete (${widget.pakete.length})',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  if (!_aufgeklappt && letztesPaket != null)
                    Text(
                      'zuletzt geholt am '
                      '${deutschesDatum(letztesPaket.geholtAm.toLocal())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                ],
              ),
              children: [
                if (widget.pakete.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Noch kein Arbeitspaket geholt.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  )
                else
                  PaketHistorieTabelle(
                    pakete: widget.pakete,
                    onLoeschen: widget.onPaketLoeschen,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zaehlerChip(
    ThemeData theme,
    String zahl,
    String label, {
    bool betont = false,
  }) {
    final scheme = theme.colorScheme;
    final ton = betont ? SoftTone.fromAccent(scheme.primary, scheme) : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ton?.background ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ton?.border ?? scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            zahl,
            style: theme.textTheme.titleMedium?.copyWith(
              color: ton?.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ton?.foreground ?? scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
