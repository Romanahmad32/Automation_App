import 'package:automation_app/core/general_widgets/form/german_date_text_field.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_feld.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:flutter/material.dart';

/// Die Kopfzeilen der Vollmacht als Eingabefelder (§4.11).
///
/// Die Felder halten eigene Controller, der Stand kommt von außen: Ändert
/// sich [kopfdaten] ohne Tastendruck — weil „wegen" dem korrigierten Namen
/// folgt oder die Art gewechselt wurde —, zieht [didUpdateWidget] genau die
/// Felder nach, deren Text abweicht. Das Feld, in dem gerade getippt wird,
/// weicht nie ab und behält damit seinen Cursor.
///
/// Gezeigt werden nur die Felder in [sichtbar] (nach der Vorlage, #171). Unter
/// jedem in [frei] steht [freiHinweis] — in der Hinweisfarbe und als
/// `helperText`, nicht als `errorText`: Ein leeres Feld hält nichts auf.
class VollmachtKopfFelder extends StatefulWidget {
  /// Der Hinweis unter einem Feld, das auf dem Papier als Linie gedruckt wird.
  static const freiHinweis = 'bleibt auf dem Papier zum Ausfüllen frei';

  final VollmachtKopfdaten kopfdaten;
  final Set<VollmachtFeld> sichtbar;
  final Set<VollmachtFeld> frei;
  final bool gesperrt;
  final ValueChanged<VollmachtKopfdaten> onGeaendert;

  const VollmachtKopfFelder({
    super.key,
    required this.kopfdaten,
    required this.sichtbar,
    required this.onGeaendert,
    this.frei = const {},
    this.gesperrt = false,
  });

  @override
  State<VollmachtKopfFelder> createState() => VollmachtKopfFelderState();
}

class VollmachtKopfFelderState extends State<VollmachtKopfFelder> {
  /// Die Zeilen des Formulars; was in einer Zeile nebeneinandersteht, teilt
  /// sich die Breite. Ein ausgeblendetes Feld räumt seinen Platz, eine leere
  /// Zeile fällt weg.
  static const _zeilen = [
    [VollmachtFeld.vorname, VollmachtFeld.nachname],
    [VollmachtFeld.strasse],
    [VollmachtFeld.plz, VollmachtFeld.ort],
    [VollmachtFeld.telefon, VollmachtFeld.email],
    [VollmachtFeld.unfalldatum],
    [VollmachtFeld.tatdatum],
    [VollmachtFeld.inSachen],
    [VollmachtFeld.wegen],
  ];

  /// Das schmale PLZ-Feld bricht den Hinweis auf drei bis vier Zeilen um;
  /// eine Vorgabe von einer Zeile schnitte ihn nach „bleibt…" ab.
  static const _hinweisZeilen = 4;

  late final Map<VollmachtFeld, TextEditingController> _felder = {
    for (final feld in VollmachtFeld.values)
      feld: TextEditingController(text: feld.wert(widget.kopfdaten)),
  };

  @override
  void didUpdateWidget(VollmachtKopfFelder oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final feld in VollmachtFeld.values) {
      final wert = feld.wert(widget.kopfdaten);
      final controller = _felder[feld]!;
      if (controller.text != wert) controller.text = wert;
    }
  }

  @override
  void dispose() {
    for (final controller in _felder.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(VollmachtFeld feld) => _felder[feld]!.text;

  void _melde() => widget.onGeaendert(
    VollmachtKopfdaten(
      vorname: _text(VollmachtFeld.vorname),
      nachname: _text(VollmachtFeld.nachname),
      strasse: _text(VollmachtFeld.strasse),
      plz: _text(VollmachtFeld.plz),
      ort: _text(VollmachtFeld.ort),
      telefon: _text(VollmachtFeld.telefon),
      email: _text(VollmachtFeld.email),
      unfalldatum: _text(VollmachtFeld.unfalldatum),
      tatdatum: _text(VollmachtFeld.tatdatum),
      inSachen: _text(VollmachtFeld.inSachen),
      wegen: _text(VollmachtFeld.wegen),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        for (final zeile in _zeilen)
          if (zeile.where(widget.sichtbar.contains).toList() case final felder
              when felder.isNotEmpty)
            _zeile(felder),
      ],
    );
  }

  Widget _zeile(List<VollmachtFeld> felder) {
    if (felder.length == 1) return _feld(felder.single);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        for (final feld in felder)
          Expanded(flex: feld == VollmachtFeld.ort ? 3 : 1, child: _feld(feld)),
      ],
    );
  }

  Widget _feld(VollmachtFeld feld) {
    final frei = widget.frei.contains(feld);
    final hinweis = frei ? VollmachtKopfFelder.freiHinweis : null;
    final hinweisStil = frei
        ? TextStyle(color: Theme.of(context).colorScheme.tertiary)
        : null;
    final key = ValueKey('vollmacht-${feld.name}');

    if (feld == VollmachtFeld.unfalldatum || feld == VollmachtFeld.tatdatum) {
      return GermanDateTextField(
        fieldKey: key,
        controller: _felder[feld]!,
        labelText: feld.beschriftung,
        enabled: !widget.gesperrt,
        isDense: true,
        onChanged: (_) => _melde(),
        helperText: hinweis,
        helperStyle: hinweisStil,
        helperMaxLines: _hinweisZeilen,
      );
    }
    return TextField(
      key: key,
      controller: _felder[feld],
      enabled: !widget.gesperrt,
      onChanged: (_) => _melde(),
      decoration: InputDecoration(
        labelText: feld.beschriftung,
        helperText: hinweis,
        helperStyle: hinweisStil,
        helperMaxLines: _hinweisZeilen,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
