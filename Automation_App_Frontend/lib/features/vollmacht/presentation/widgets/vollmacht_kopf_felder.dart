import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_kopfdaten.dart';
import 'package:flutter/material.dart';

/// Die Kopfzeilen der Vollmacht als Eingabefelder (§4.11).
///
/// Die Felder halten eigene Controller, der Stand kommt von außen: Ändert
/// sich [kopfdaten] ohne Tastendruck — weil „wegen" dem korrigierten Namen
/// folgt oder die Art gewechselt wurde —, zieht [didUpdateWidget] genau die
/// Felder nach, deren Text abweicht. Das Feld, in dem gerade getippt wird,
/// weicht nie ab und behält damit seinen Cursor.
class VollmachtKopfFelder extends StatefulWidget {
  final VollmachtKopfdaten kopfdaten;
  final VollmachtArt? art;
  final bool gesperrt;
  final ValueChanged<VollmachtKopfdaten> onGeaendert;

  const VollmachtKopfFelder({
    super.key,
    required this.kopfdaten,
    required this.art,
    required this.onGeaendert,
    this.gesperrt = false,
  });

  @override
  State<VollmachtKopfFelder> createState() => VollmachtKopfFelderState();
}

class VollmachtKopfFelderState extends State<VollmachtKopfFelder> {
  late final Map<String, TextEditingController> _felder = {
    for (final eintrag in _werte(widget.kopfdaten).entries)
      eintrag.key: TextEditingController(text: eintrag.value),
  };

  static Map<String, String> _werte(VollmachtKopfdaten k) => {
    'vorname': k.vorname,
    'nachname': k.nachname,
    'strasse': k.strasse,
    'plz': k.plz,
    'ort': k.ort,
    'telefon': k.telefon,
    'email': k.email,
    'unfalldatum': k.unfalldatum,
    'inSachen': k.inSachen,
    'wegen': k.wegen,
  };

  @override
  void didUpdateWidget(VollmachtKopfFelder oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final eintrag in _werte(widget.kopfdaten).entries) {
      final controller = _felder[eintrag.key]!;
      if (controller.text != eintrag.value) controller.text = eintrag.value;
    }
  }

  @override
  void dispose() {
    for (final controller in _felder.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _melde() => widget.onGeaendert(
    VollmachtKopfdaten(
      vorname: _felder['vorname']!.text,
      nachname: _felder['nachname']!.text,
      strasse: _felder['strasse']!.text,
      plz: _felder['plz']!.text,
      ort: _felder['ort']!.text,
      telefon: _felder['telefon']!.text,
      email: _felder['email']!.text,
      unfalldatum: _felder['unfalldatum']!.text,
      inSachen: _felder['inSachen']!.text,
      wegen: _felder['wegen']!.text,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final unfall = widget.art == VollmachtArt.unfallsachen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        _zeile([_feld('vorname', 'Vorname'), _feld('nachname', 'Nachname')]),
        _feld('strasse', 'Straße und Hausnummer'),
        _zeile([_feld('plz', 'PLZ'), _feld('ort', 'Ort', flex: 3)]),
        _zeile([_feld('telefon', 'Telefon'), _feld('email', 'E-Mail')]),
        if (unfall) _feld('unfalldatum', 'Unfalldatum'),
        _feld('inSachen', 'in Sachen'),
        _feld('wegen', 'wegen'),
      ],
    );
  }

  Widget _zeile(List<Widget> felder) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: felder,
  );

  Widget _feld(String schluessel, String label, {int flex = 1}) {
    final feld = TextField(
      key: ValueKey('vollmacht-$schluessel'),
      controller: _felder[schluessel],
      enabled: !widget.gesperrt,
      onChanged: (_) => _melde(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
    return switch (schluessel) {
      'strasse' || 'unfalldatum' || 'inSachen' || 'wegen' => feld,
      _ => Expanded(flex: flex, child: feld),
    };
  }
}
