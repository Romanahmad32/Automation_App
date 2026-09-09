import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_stand.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/jahrgang_stand_chip.dart';
import 'package:flutter/material.dart';

/// Die Zeile „Historie" über der Filterleiste des Registers (§6.2): Woher das
/// übernommene Registerbuch reicht, welche Jahrgänge fehlen und wo Lücken
/// offen blieben — dazu der Weg, daran etwas zu ändern.
///
/// Sie steht **über** der Tabelle und nicht in den Einstellungen: Der Anwalt
/// soll sehen, dass 2021 fehlt, während er im Register blättert — und nicht
/// erst, wenn er danach sucht.
///
/// Sie ist dabei eine **Zeile** und keine Karte mehr. Als Karte mit ausgelegter
/// Chipreihe nahm sie das obere Drittel der Seite ein, obwohl der Anwalt sie an
/// den meisten Tagen nur überfliegt: Der Satz sagt, ob etwas fehlt, und erst
/// „Details" legt die Jahrgänge einzeln auf.
class HistorieStandLeiste extends StatefulWidget {
  final RegisterHistorieStand stand;

  /// Öffnet die Import-Seite. Als Rückruf und nicht als Route hier drin, damit
  /// die Zeile für sich testbar bleibt. Die Anleitung für den Erzeuger der
  /// Datei steht dort gleich daneben — ein eigener Knopf dafür war ein zweiter
  /// Weg zur selben Seite.
  final VoidCallback? onDateiEinlesen;

  /// Klick auf einen Jahrgangs-Chip: stellt die Spanne darunter auf genau
  /// diesen Jahrgang.
  final ValueChanged<int>? onJahrgang;

  /// Der Jahrgang, auf dem die Spanne gerade steht, sofern sie genau einen
  /// umfasst — der Chip dazu wird hervorgehoben.
  final int? gewaehlterJahrgang;

  const HistorieStandLeiste({
    super.key,
    required this.stand,
    this.onDateiEinlesen,
    this.onJahrgang,
    this.gewaehlterJahrgang,
  });

  @override
  State<HistorieStandLeiste> createState() => HistorieStandLeisteState();
}

class HistorieStandLeisteState extends State<HistorieStandLeiste> {
  bool _offen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final jahrgaenge = _jahrgaenge();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _kopfzeile(theme, jahrgaenge.isNotEmpty),
          if (_offen && jahrgaenge.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _chips(jahrgaenge),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kopfzeile(ThemeData theme, bool mitDetails) {
    final scheme = theme.colorScheme;
    return Row(
      spacing: 8,
      children: [
        Icon(Icons.history_edu_outlined, size: 18, color: scheme.outline),
        Expanded(
          child: Text(
            _satz(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: _etwasOffen ? scheme.onSurface : scheme.outline,
            ),
          ),
        ),
        if (mitDetails)
          TextButton.icon(
            onPressed: () => setState(() => _offen = !_offen),
            icon: Icon(
              _offen ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: const Text('Details'),
          ),
        OutlinedButton.icon(
          onPressed: widget.onDateiEinlesen,
          icon: const Icon(Icons.file_upload_outlined, size: 18),
          label: const Text('Datei einlesen…'),
        ),
      ],
    );
  }

  /// Der ganze Stand in einem Satz: „Historie ab 2018 · 2021 fehlt · 3 offene
  /// Lücken". Kein festes Startjahr — wie weit das Registerbuch zurückreicht,
  /// sagt der Bestand und nicht eine Zahl im Code.
  String _satz() {
    final kleinster = widget.stand.kleinsterJahrgang;
    if (kleinster == null) return 'Noch keine Historie übernommen';

    final fehlende = widget.stand.fehlendeJahrgaenge;
    final luecken = _luecken();
    return [
      'Historie ab $kleinster',
      if (fehlende.length == 1) '${fehlende.single} fehlt',
      if (fehlende.length > 1) '${fehlende.join(', ')} fehlen',
      if (luecken == 1) '1 offene Lücke',
      if (luecken > 1) '$luecken offene Lücken',
    ].join(' · ');
  }

  /// Ob an der Übernahme noch etwas offen ist. Dann steht der Satz in der
  /// Schriftfarbe der Seite statt grau: Eine Zeile, die man überfliegt, muss
  /// sich melden, wenn sie etwas zu sagen hat — und stillhalten, wenn nicht.
  bool get _etwasOffen =>
      _luecken() > 0 || widget.stand.fehlendeJahrgaenge.isNotEmpty;

  int _luecken() => widget.stand.jahrgaenge.fold(
    0,
    (summe, jahrgang) => summe + jahrgang.luecken.length,
  );

  /// Übernommene und fehlende Jahrgänge in einer Folge, aufsteigend — die
  /// Lücke soll zwischen ihren Nachbarn stehen und nicht am Ende.
  List<int> _jahrgaenge() {
    final jahre = <int>{
      ...widget.stand.jahrgaenge.map((eintrag) => eintrag.jahrgang),
      ...widget.stand.fehlendeJahrgaenge,
    }.toList();
    jahre.sort();
    return jahre;
  }

  List<Widget> _chips(List<int> jahrgaenge) => [
    for (final jahrgang in jahrgaenge)
      JahrgangStandChip(
        jahrgang: jahrgang,
        stand: widget.stand.zuJahrgang(jahrgang),
        ausgewaehlt: widget.gewaehlterJahrgang == jahrgang,
        onTap: widget.onJahrgang == null
            ? null
            : () => widget.onJahrgang!(jahrgang),
      ),
  ];
}
