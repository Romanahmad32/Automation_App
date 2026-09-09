import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/abteilung_auswahl.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/rechtsgebiet_auswahl.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Karte „Auftrag" oben im Formular: laufende Auftragsnummer, Jahr und
/// Abteilung. Die Abteilung ist die **einzige** Sachgebiets-Entscheidung
/// (§7.1): Sie kommt als Haupt-/Nebensachgebiet aus dem Katalog
/// ([AbteilungAuswahl], schreibt das FormControl `abteilung`), und das
/// Rechtsgebiet darunter folgt ihr ([RechtsgebietAuswahl]) statt ein zweites
/// Mal dasselbe zu fragen.
///
/// Das Rechtsgebiet liegt als lokaler State der View — es steuert, ob die
/// Unfall-Abschnitte sichtbar und ihre Felder Pflicht werden.
class AuftragSection extends StatelessWidget {
  final String rechtsgebiet;

  /// Ob das Rechtsgebiet von Hand gesetzt wurde und der Abteilung deshalb
  /// nicht mehr folgt.
  final bool rechtsgebietManuell;

  final ValueChanged<String> onRechtsgebietChanged;
  final VoidCallback onRechtsgebietAbweichend;
  final VoidCallback onRechtsgebietFolgtWieder;

  const AuftragSection({
    super.key,
    required this.rechtsgebiet,
    required this.rechtsgebietManuell,
    required this.onRechtsgebietChanged,
    required this.onRechtsgebietAbweichend,
    required this.onRechtsgebietFolgtWieder,
  });

  @override
  Widget build(BuildContext context) {
    return FormSection(
      icon: Icons.assignment_outlined,
      title: 'Auftrag',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              flex: 3,
              child: GeneralTextField<String>(
                labelText: 'Auftragsnummer',
                formControlName: 'auftragsnummer',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GeneralTextField<String>(
                labelText: 'Jahr',
                formControlName: 'auftragsjahr',
              ),
            ),
          ],
        ),
        const AbteilungAuswahl(),
        // Die Abteilung kommt aus dem Formular statt durch die Sektionsliste
        // gereicht: Sie steht im selben FormControl, das die Auswahl darüber
        // schreibt, und die Ableitung soll ihr ohne Umweg folgen.
        ReactiveValueListenableBuilder<String>(
          formControlName: 'abteilung',
          builder: (context, control, _) => RechtsgebietAuswahl(
            rechtsgebiet: rechtsgebiet,
            abteilung: control.value ?? '',
            manuell: rechtsgebietManuell,
            onChanged: onRechtsgebietChanged,
            onAbweichend: onRechtsgebietAbweichend,
            onFolgtWieder: onRechtsgebietFolgtWieder,
          ),
        ),
      ],
    );
  }
}
