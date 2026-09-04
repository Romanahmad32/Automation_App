import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/ganzzahl_feld_klein.dart';
import 'package:flutter/material.dart';

/// Stellt die Vorbelegung eines Datumsfelds ein (§5.3): vier Zahlenfelder für
/// Jahre, Monate, Wochen und Tage, daneben das Datum, das heute dabei
/// herauskäme.
///
/// Die Vorschau ist der Sinn der Sache. „5 Wochen" sagt dem Anwalt nicht, ob
/// das Schreiben dann noch in seinen Urlaub fällt — ein Datum sagt es. Und
/// weil hier keine Fristenlogik läuft (§8: keine Werktagsverschiebung, keine
/// Feiertage), muss der gerechnete Tag sichtbar sein, statt erst im erzeugten
/// Dokument aufzufallen.
///
/// **Ist [vorbelegung] null, ist am Feld nichts eingestellt**: Dann zeigen die
/// Zahlenfelder, was die Namensregel aus [feldname] ableitet, und ein
/// Kennzeichen macht das kenntlich. Die erste Eingabe macht daraus eine feste
/// Einstellung — das Kennzeichen weicht einem „Zurücksetzen"-Knopf, der mit
/// [onChanged]`(null)` wieder zur Ableitung zurückkehrt. Deshalb meldet
/// [onChanged] bei jeder Eingabe immer eine ausdrückliche [DatumsVorbelegung],
/// auch die aus lauter Nullen („bewusst heute", siehe `FieldData`).
class DatumsVorbelegungEditor extends StatefulWidget {
  /// Die eingestellte Vorbelegung, oder null für „nie angefasst".
  final DatumsVorbelegung? vorbelegung;

  /// Der Feldname, aus dem abgeleitet wird, solange nichts eingestellt ist.
  /// Auf der Detailseite steht er im Formular-Control und ändert sich, während
  /// der Anwalt tippt — die Ableitung läuft deshalb mit.
  final String feldname;

  final ValueChanged<DatumsVorbelegung?> onChanged;

  const DatumsVorbelegungEditor({
    super.key,
    required this.vorbelegung,
    required this.feldname,
    required this.onChanged,
  });

  @override
  State<DatumsVorbelegungEditor> createState() =>
      _DatumsVorbelegungEditorState();
}

class _DatumsVorbelegungEditorState extends State<DatumsVorbelegungEditor> {
  late final TextEditingController _jahre;
  late final TextEditingController _monate;
  late final TextEditingController _wochen;
  late final TextEditingController _tage;

  /// Was von aussen gelten soll: die eingestellte Vorbelegung, sonst die aus
  /// dem Feldnamen abgeleitete.
  DatumsVorbelegung get _vorgabe =>
      widget.vorbelegung ?? DatumsVorbelegung.ausFeldname(widget.feldname);

  /// Was in den Feldern steht. Leer zählt als 0 — daraus entsteht die Meldung
  /// nach draussen und die Vorschau, damit beides sofort zum Getippten passt
  /// und nicht erst, wenn der Aufrufer den Wert zurückreicht.
  DatumsVorbelegung get _eingestellt => DatumsVorbelegung(
    jahre: _zahl(_jahre),
    monate: _zahl(_monate),
    wochen: _zahl(_wochen),
    tage: _zahl(_tage),
  );

  @override
  void initState() {
    super.initState();
    final vorgabe = _vorgabe;
    _jahre = TextEditingController(text: '${vorgabe.jahre}');
    _monate = TextEditingController(text: '${vorgabe.monate}');
    _wochen = TextEditingController(text: '${vorgabe.wochen}');
    _tage = TextEditingController(text: '${vorgabe.tage}');
  }

  @override
  void didUpdateWidget(DatumsVorbelegungEditor alt) {
    super.didUpdateWidget(alt);
    final vorgabe = _vorgabe;
    // Nur nachziehen, wenn die Änderung von **aussen** kommt. Kommt sie aus
    // der eigenen Meldung zurück, stehen die Felder schon richtig: Sie neu zu
    // setzen zöge den Cursor ans Ende und machte aus einem gerade geleerten
    // Feld wieder eine „0" — mitten im Tippen.
    if (vorgabe == _eingestellt) return;
    _setze(_jahre, vorgabe.jahre);
    _setze(_monate, vorgabe.monate);
    _setze(_wochen, vorgabe.wochen);
    _setze(_tage, vorgabe.tage);
  }

  @override
  void dispose() {
    _jahre.dispose();
    _monate.dispose();
    _wochen.dispose();
    _tage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final datum = deutschesDatum(_eingestellt.anwendenAuf(DateTime.now()));
    final abgeleitet = widget.vorbelegung == null;
    // Wrap statt Row: Die Karte ist meist breit genug für eine Zeile, aber bei
    // wenig Platz rutscht die Vorschau (oder ein Feld) in eine zweite Zeile,
    // statt seitlich abgeschnitten zu werden.
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_repeat,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text('Vorbelegung: heute +', style: theme.textTheme.bodyMedium),
          ],
        ),
        GanzzahlFeldKlein(
          controller: _jahre,
          labelText: 'Jahre',
          onChanged: _geaendert,
        ),
        GanzzahlFeldKlein(
          controller: _monate,
          labelText: 'Monate',
          onChanged: _geaendert,
        ),
        GanzzahlFeldKlein(
          controller: _wochen,
          labelText: 'Wochen',
          onChanged: _geaendert,
        ),
        GanzzahlFeldKlein(
          controller: _tage,
          labelText: 'Tage',
          onChanged: _geaendert,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_forward,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text('ergibt ', style: theme.textTheme.bodyMedium),
            Text(
              datum,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (abgeleitet) _ableitungsBadge(theme) else _zuruecksetzenButton(),
      ],
    );
  }

  /// Solange nichts eingestellt ist, sagt dieses Kennzeichen, dass die Werte
  /// aus der Namensregel stammen — in der Optik von `FeldVorkommenBadge`
  /// (schmaler Rahmen, `labelSmall`, dieselbe Rundung), damit es zu den
  /// übrigen Kennzeichen der Karte passt.
  static Widget _ableitungsBadge(ThemeData theme) {
    final farbe = theme.colorScheme.onSurfaceVariant;
    return Tooltip(
      message: _ableitungsTooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: farbe),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'abgeleitet',
          style: theme.textTheme.labelSmall?.copyWith(color: farbe),
        ),
      ),
    );
  }

  static const _ableitungsTooltip =
      'Aus dem Feldnamen abgeleitet. Sobald du einen Wert änderst, gilt die '
      'Einstellung fest für dieses Feld.';

  /// Ersetzt das Kennzeichen, sobald eine Einstellung feststeht: der Weg
  /// zurück zur Ableitung, ohne die Zahlenfelder einzeln auf 0 zu setzen.
  Widget _zuruecksetzenButton() {
    return TextButton.icon(
      onPressed: () => widget.onChanged(null),
      icon: const Icon(Icons.undo, size: 16),
      label: const Text('Zurücksetzen'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Jede Eingabe meldet einen ausdrücklichen Wert nach draussen. `setState`
  /// dazu, damit die Vorschau mittippt, auch wenn der Aufrufer den Stand erst
  /// später zurückreicht.
  void _geaendert(String _) {
    setState(() {});
    widget.onChanged(_eingestellt);
  }

  static int _zahl(TextEditingController feld) =>
      int.tryParse(feld.text.trim()) ?? 0;

  static void _setze(TextEditingController feld, int wert) {
    final text = '$wert';
    if (feld.text == text) return;
    feld.text = text;
  }
}
