import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Übernimmt die Vorbelegung des Formulars aus `VorgangStartenDefaultsLoaded`
/// (laufende Auftragsnummer/Abteilung, §6.3) — sowohl beim Öffnen der Seite
/// (der Bloc kann schon geladen haben, bevor dieses Widget zum ersten Mal
/// baut) als auch bei jedem späteren Übergang in diesen Zustand. Ein bloßer
/// `BlocListener` allein sähe den bereits erreichten Zustand beim Mounten
/// nicht (siehe `Automation_App_Frontend/CLAUDE.md`, „Formular aus einem Bloc
/// füllen"); deshalb der zusätzliche Check im `initState`.
///
/// [onNummernstandGeladen] trägt den Bestand für die Belegt-Warnung (§6.3)
/// nach oben — die View hält ihn als lokalen State, weil `AuftragSection`
/// (über `VorgangStartenSektionen`) ihn braucht, aber kein zweiter
/// Bloc-Zugriff an der Sektion selbst hängen soll.
class VorgangDefaultsBeobachter extends StatefulWidget {
  final FormGroup form;
  final void Function(List<int> belegteNummern, String? nummernJahr)
  onNummernstandGeladen;
  final Widget child;

  const VorgangDefaultsBeobachter({
    super.key,
    required this.form,
    required this.onNummernstandGeladen,
    required this.child,
  });

  @override
  State<VorgangDefaultsBeobachter> createState() =>
      _VorgangDefaultsBeobachterState();
}

class _VorgangDefaultsBeobachterState extends State<VorgangDefaultsBeobachter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<VorgangStartenBloc>().state;
      if (state is VorgangStartenDefaultsLoaded) _patchDefaults(state);
    });
  }

  void _patchDefaults(VorgangStartenDefaultsLoaded state) {
    widget.form
        .control('auftragsnummer')
        .updateValue(state.auftragsnummer.toString());
    // Kürzel ohne Leerzeichen (§7.1) — ein gespeicherter Altwert wie 'C 03'
    // wird beim Einlesen normalisiert, bevor er in die Referenz wandert.
    final bereinigt = AbteilungKuerzel.normalisiere(state.abteilung);
    if (bereinigt.isNotEmpty) {
      widget.form.control('abteilung').updateValue(bereinigt);
    }
    widget.onNummernstandGeladen(state.belegteNummern, state.nummernJahr);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VorgangStartenBloc, VorgangStartenState>(
      listener: (context, state) {
        if (state is VorgangStartenDefaultsLoaded) _patchDefaults(state);
      },
      child: widget.child,
    );
  }
}
