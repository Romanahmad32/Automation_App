import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/anrede_auswahl.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/kennzeichen_editor.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die Eingabefelder der Mandanten-Stammdaten (§5.1) — der Inhalt der
/// `FormSection` auf `MandantDetailsPage`.
///
/// Eigenes Widget, weil die Seite sonst über der Zeilengrenze läge: Sie hält
/// Formular, Speichern und Fehlermeldung; die Felder sind eine Sache für sich
/// und wachsen unabhängig davon.
///
/// **Anrede und Kennzeichen laufen nicht über die `FormGroup`**, sondern über
/// [onAnredeChanged] und [onKennzeichenChanged] zurück an die Seite — beide
/// haben einen eigenen Editor mit eigenem Zustand. Wer hier ein Feld ergänzt,
/// das ein gewöhnliches Textfeld ist, trägt es dagegen in die `FormGroup` der
/// Seite ein und liest es dort beim Speichern aus.
class MandantStammdatenFelder extends StatelessWidget {
  final Anrede anrede;
  final ValueChanged<Anrede> onAnredeChanged;
  final List<String> kennzeichen;
  final ValueChanged<List<String>> onKennzeichenChanged;

  const MandantStammdatenFelder({
    super.key,
    required this.anrede,
    required this.onAnredeChanged,
    required this.kennzeichen,
    required this.onKennzeichenChanged,
  });

  @override
  Widget build(BuildContext context) {
    final beschriftung = Theme.of(context).textTheme.labelLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        _ueberschrift('Anrede', beschriftung),
        AnredeAuswahl(initialAnrede: anrede, onChanged: onAnredeChanged),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _feld('vorname', 'Vorname')),
            const SizedBox(width: 12),
            Expanded(
              child: _feld(
                'nachname',
                'Nachname *',
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      'Der Nachname ist ein Pflichtfeld',
                },
              ),
            ),
          ],
        ),
        _feld('strasseHausnummer', 'Straße und Hausnummer'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _feld('postleitzahl', 'PLZ')),
            const SizedBox(width: 12),
            Expanded(flex: 5, child: _feld('ort', 'Ort')),
          ],
        ),
        _feld(
          'emailAdresse',
          'E-Mail-Adresse',
          keyboardType: TextInputType.emailAddress,
          validationMessages: {
            ValidationMessage.email: (_) =>
                'Bitte eine gültige E-Mail-Adresse eingeben',
          },
        ),
        _feld(
          'telefonnummer',
          'Telefonnummer',
          keyboardType: TextInputType.phone,
        ),
        _feld(
          'persoenlicheGrussformel',
          'Persönliche Grußformel (optional)',
          dekoration: const InputDecoration(
            hintText: 'z. B. Salamu aleikum',
            helperText:
                'Steht in Mails an diesen Mandanten unter der Anrede — nur, '
                'wenn sonst niemand mitliest. Leer lassen heißt: kein Zusatzgruß.',
            helperMaxLines: 3,
          ),
        ),
        _feld('notiz', 'Notiz', maxLines: 3),
        const SizedBox(height: 4),
        _ueberschrift('Kennzeichen (optional)', beschriftung),
        KennzeichenEditor(
          initialKennzeichen: kennzeichen,
          onChanged: onKennzeichenChanged,
        ),
      ],
    );
  }

  Widget _ueberschrift(String text, TextStyle? stil) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: stil),
  );

  Widget _feld(
    String controlName,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    InputDecoration? dekoration,
    Map<String, String Function(Object)>? validationMessages,
  }) {
    return GeneralTextField<String>(
      formControlName: controlName,
      labelText: label,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputDecoration: dekoration,
      validationMessages: validationMessages,
    );
  }
}
