import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_aenderung.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/vorgang_dialog_field.dart';
import 'package:flutter/material.dart';

/// Die sieben Eingabefelder einer historischen Registerzeile, gebündelt.
///
/// Eigene Klasse, weil der Dialog daneben sonst aus sieben Controllern, sieben
/// Zuweisungen und sieben `dispose()` bestünde — und weil das Umrechnen in eine
/// [RegisterHistorieAenderung] genau eine Stelle haben soll.
class HistorieZeileFelder {
  final TextEditingController abteilung;
  final TextEditingController sachart;
  final TextEditingController mandant;
  final TextEditingController gegner;
  final TextEditingController sachbestand;
  final TextEditingController unfalldatum;
  final TextEditingController rechtsgebiet;

  HistorieZeileFelder.ausAenderung(RegisterHistorieAenderung aenderung)
    : abteilung = TextEditingController(text: aenderung.abteilung),
      sachart = TextEditingController(text: aenderung.sachart),
      mandant = TextEditingController(text: aenderung.mandant),
      gegner = TextEditingController(text: aenderung.gegner),
      sachbestand = TextEditingController(text: aenderung.sachbestand),
      unfalldatum = TextEditingController(text: aenderung.unfalldatum),
      rechtsgebiet = TextEditingController(text: aenderung.rechtsgebiet);

  RegisterHistorieAenderung alsAenderung() => RegisterHistorieAenderung(
    abteilung: abteilung.text.trim(),
    sachart: sachart.text.trim(),
    mandant: mandant.text.trim(),
    gegner: gegner.text.trim(),
    sachbestand: sachbestand.text.trim(),
    unfalldatum: unfalldatum.text.trim(),
    rechtsgebiet: rechtsgebiet.text.trim(),
  );

  void dispose() {
    abteilung.dispose();
    sachart.dispose();
    mandant.dispose();
    gegner.dispose();
    sachbestand.dispose();
    unfalldatum.dispose();
    rechtsgebiet.dispose();
  }
}

/// Das Formular des Bearbeiten-Dialogs für eine historische Registerzeile.
///
/// Jahr und laufende Nummer stehen bewusst **nicht** darin: Sie sind der
/// natürliche Schlüssel des Registers. Wären sie änderbar, könnte eine
/// Berichtigung eine zweite Zeile überschreiben oder eine Lücke aufreißen, die
/// vorher keine war.
class HistorieZeileFormular extends StatelessWidget {
  final HistorieZeileFelder felder;

  const HistorieZeileFormular({super.key, required this.felder});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      VorgangDialogField(
        controller: felder.abteilung,
        label: 'Abteilung (z. B. C03)',
      ),
      VorgangDialogField(
        controller: felder.sachart,
        label: 'Sachart (z. B. Bußgeldsache) — leer, wenn es einen Gegner gibt',
      ),
      VorgangDialogField(controller: felder.mandant, label: 'Mandant'),
      VorgangDialogField(
        controller: felder.gegner,
        label: 'Gegner — leer, wenn es keine Gegenseite gibt',
      ),
      VorgangDialogField(
        controller: felder.sachbestand,
        label: 'Sachbestand (z. B. Unfall)',
      ),
      VorgangDialogField(
        controller: felder.unfalldatum,
        label: 'Unfalldatum (wie im Register, z. B. 28.12.17)',
      ),
      VorgangDialogField(
        controller: felder.rechtsgebiet,
        label: 'Rechtsgebiet',
      ),
    ],
  );
}
