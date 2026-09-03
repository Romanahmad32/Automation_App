import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/datums_vorbelegung.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/ganzzahl_feld_klein.dart';
import 'package:flutter/material.dart';

/// Stellt die Vorbelegung eines Datumsfelds ein (§5.3): vier Zahlenfelder für
/// Jahre, Monate, Wochen und Tage, darunter das Datum, das heute dabei
/// herauskäme.
///
/// Die Vorschauzeile ist der Sinn der Sache. „5 Wochen" sagt dem Anwalt nicht,
/// ob das Schreiben dann noch in seinen Urlaub fällt — ein Datum sagt es. Und
/// weil hier keine Fristenlogik läuft (§8: keine Werktagsverschiebung, keine
/// Feiertage), muss der gerechnete Tag sichtbar sein, statt erst im erzeugten
/// Dokument aufzufallen.
///
/// **Ist [vorbelegung] null, ist am Feld nichts eingestellt**: Dann zeigen die
/// Zahlenfelder, was die Namensregel aus [feldname] ableitet, und die Vorschau
/// sagt es dazu. Die erste Eingabe macht daraus eine feste Einstellung —
/// deshalb meldet [onChanged] immer eine ausdrückliche [DatumsVorbelegung],
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
    final zusatz = widget.vorbelegung == null ? ' $_ableitungsHinweis' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Vorbelegt mit heute +', style: theme.textTheme.bodySmall),
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
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'ergibt heute: $datum$zusatz',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  static const _ableitungsHinweis =
      '(aus dem Feldnamen abgeleitet — Änderung macht es zur festen '
      'Einstellung)';

  /// Jede Eingabe meldet einen ausdrücklichen Wert nach draussen. `setState`
  /// dazu, damit die Vorschauzeile mittippt, auch wenn der Aufrufer den Stand
  /// erst später zurückreicht.
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
