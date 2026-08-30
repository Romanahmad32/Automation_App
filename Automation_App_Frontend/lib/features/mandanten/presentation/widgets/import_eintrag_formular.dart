import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/core/general_widgets/form/texte_listen_editor.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/anrede_auswahl.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/kennzeichen_editor.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die Felder einer Importzeile — dieselben Stammdaten wie im Mandantenformular
/// (§5.1), dazu die Akten-Ordner, die dieser Zeile zugeschrieben sind.
///
/// Die Ordnerliste ist der Grund, warum es dieses Formular gibt: eine
/// maschinell erzeugte Datei verwechselt eher einen Ordner als eine Anschrift,
/// und die Zuordnung ist das, was der Import wirklich anrichtet.
///
/// Nicht bearbeitbar sind `quelle` und `sicherheit`. Sie beschreiben den Fund,
/// nicht den Mandanten — wer sie überschriebe, verlöre die Auskunft darüber,
/// woher die Angaben stammen, und behielte nur noch die Angaben.
///
/// Braucht ein [ReactiveForm] über sich; die `FormGroup` spannt der Dialog auf,
/// weil sein „Übernehmen" außerhalb dieses Widgets liegt und trotzdem sehen
/// muss, ob das Formular gültig ist.
class ImportEintragFormular extends StatelessWidget {
  final Anrede initialAnrede;
  final List<String> initialOrdnernamen;
  final List<String> initialKennzeichen;
  final ValueChanged<Anrede> onAnrede;
  final ValueChanged<List<String>> onOrdnernamen;
  final ValueChanged<List<String>> onKennzeichen;

  const ImportEintragFormular({
    super.key,
    required this.initialAnrede,
    required this.initialOrdnernamen,
    required this.initialKennzeichen,
    required this.onAnrede,
    required this.onOrdnernamen,
    required this.onKennzeichen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        AnredeAuswahl(initialAnrede: initialAnrede, onChanged: onAnrede),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: GeneralTextField<String>(
                formControlName: 'vorname',
                labelText: 'Vorname',
              ),
            ),
            Expanded(
              child: GeneralTextField<String>(
                formControlName: 'nachname',
                labelText: 'Nachname',
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      'Ohne Nachnamen lässt sich kein Mandant anlegen',
                },
              ),
            ),
          ],
        ),
        GeneralTextField<String>(
          formControlName: 'strasseHausnummer',
          labelText: 'Straße und Hausnummer',
        ),
        Row(
          spacing: 12,
          children: [
            SizedBox(
              width: 140,
              child: GeneralTextField<String>(
                formControlName: 'postleitzahl',
                labelText: 'Postleitzahl',
              ),
            ),
            Expanded(
              child: GeneralTextField<String>(
                formControlName: 'ort',
                labelText: 'Ort',
              ),
            ),
          ],
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: GeneralTextField<String>(
                formControlName: 'emailAdresse',
                labelText: 'E-Mail',
                validationMessages: {
                  ValidationMessage.email: (_) => 'Keine gültige E-Mail',
                },
              ),
            ),
            Expanded(
              child: GeneralTextField<String>(
                formControlName: 'telefonnummer',
                labelText: 'Telefon',
              ),
            ),
          ],
        ),
        GeneralTextField<String>(
          formControlName: 'notiz',
          labelText: 'Notiz',
          maxLines: 2,
        ),
        TexteListenEditor(
          initialWerte: initialOrdnernamen,
          onChanged: onOrdnernamen,
          labelText: 'Akten-Ordner',
          helperText: 'Nur der Ordnername unter dem Stammordner, kein Pfad',
          chipIcon: Icons.folder_outlined,
          entfernenTooltip: 'Ordner aus dieser Zeile nehmen',
          hinzufuegenTooltip: 'Ordner hinzufügen',
          dublettenHinweis: 'Dieser Ordner steht bereits in der Zeile',
        ),
        KennzeichenEditor(
          initialKennzeichen: initialKennzeichen,
          onChanged: onKennzeichen,
        ),
      ],
    );
  }
}
