import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/anrede_auswahl.dart';
import 'package:automation_app/features/word_automation/presentation/utils/formular_extraktion.dart';
import 'package:flutter/material.dart';

/// Dialog zum Anlegen eines neuen Mandanten direkt aus dem Speicherschritt,
/// vorbelegt mit den (best-effort) aus dem Formular gelesenen Daten.
class NeuerMandantDialog extends StatefulWidget {
  final FormularMandantDaten vorschlag;

  const NeuerMandantDialog({super.key, required this.vorschlag});

  @override
  State<NeuerMandantDialog> createState() => _NeuerMandantDialogState();
}

class _NeuerMandantDialogState extends State<NeuerMandantDialog> {
  late final _vorname = TextEditingController(text: widget.vorschlag.vorname);
  late final _nachname = TextEditingController(text: widget.vorschlag.nachname);
  late final _strasse = TextEditingController(
    text: widget.vorschlag.strasseHausnummer,
  );
  late final _plz = TextEditingController(text: widget.vorschlag.postleitzahl);
  late final _ort = TextEditingController(text: widget.vorschlag.ort);
  late final _email = TextEditingController(
    text: widget.vorschlag.emailAdresse,
  );
  late final _telefon = TextEditingController(
    text: widget.vorschlag.telefonnummer,
  );

  Anrede _anrede = Anrede.keine;

  @override
  void dispose() {
    for (final c in [
      _vorname,
      _nachname,
      _strasse,
      _plz,
      _ort,
      _email,
      _telefon,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuen Mandanten anlegen'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnredeAuswahl(
                initialAnrede: _anrede,
                onChanged: (wert) => _anrede = wert,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _feld(_vorname, 'Vorname')),
                  const SizedBox(width: 12),
                  Expanded(child: _feld(_nachname, 'Nachname *')),
                ],
              ),
              const SizedBox(height: 12),
              _feld(_strasse, 'Straße und Hausnummer'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(flex: 2, child: _feld(_plz, 'PLZ')),
                  const SizedBox(width: 12),
                  Expanded(flex: 5, child: _feld(_ort, 'Ort')),
                ],
              ),
              const SizedBox(height: 12),
              _feld(_email, 'E-Mail-Adresse'),
              const SizedBox(height: 12),
              _feld(_telefon, 'Telefonnummer'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            if (_nachname.text.trim().isEmpty) {
              Rueckmeldung.zeigeHinweis(
                context,
                'Der Nachname ist ein Pflichtfeld',
              );
              return;
            }
            Navigator.pop(
              context,
              CreateMandantRequest(
                anrede: _anrede,
                vorname: _vorname.text.trim(),
                nachname: _nachname.text.trim(),
                strasseHausnummer: _strasse.text.trim(),
                postleitzahl: _plz.text.trim(),
                ort: _ort.text.trim(),
                emailAdresse: _email.text.trim(),
                telefonnummer: _telefon.text.trim(),
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }

  Widget _feld(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
