import 'package:automation_app/features/email_versand/domain/entities/email_empfaenger_vorschlag.dart';
import 'package:automation_app/features/email_versand/domain/entities/empfaenger_art.dart';
import 'package:flutter/material.dart';

/// Eine Empfängerzeile („An" oder „Kopie"): die bereits gewählten Adressen als
/// entfernbare Chips, ein Feld zum Eintippen und die Adressen, die die App zum
/// Vorgang schon kennt (§4.7).
///
/// Eintippen und Anklicken stehen bewusst nebeneinander: Der Regelfall ist der
/// Klick auf Mandant und Versicherung, der Sonderfall (Sachverständiger,
/// Werkstatt) muss trotzdem ohne Umweg möglich sein. Die Vorschläge stehen an
/// **beiden** Zeilen — der Mandant bekommt das Schreiben oft nur in Kopie.
class EmailEmpfaengerFeld extends StatefulWidget {
  final String titel;
  final List<String> adressen;
  final List<EmailEmpfaengerVorschlag> vorschlaege;

  /// Alle schon vergebenen Adressen der Mail, über beide Zeilen hinweg. Eine
  /// Adresse, die oben in „An" steht, darf unten nicht mehr als Vorschlag
  /// erscheinen: Der Klick bliebe wirkungslos, weil niemand zweimal
  /// angeschrieben wird.
  final List<String> bereitsVergeben;

  final ValueChanged<String> onHinzufuegen;
  final ValueChanged<String> onEntfernen;
  final bool aktiv;

  const EmailEmpfaengerFeld({
    super.key,
    required this.titel,
    required this.adressen,
    required this.onHinzufuegen,
    required this.onEntfernen,
    this.vorschlaege = const [],
    this.bereitsVergeben = const [],
    this.aktiv = true,
  });

  @override
  State<EmailEmpfaengerFeld> createState() => _EmailEmpfaengerFeldState();
}

class _EmailEmpfaengerFeldState extends State<EmailEmpfaengerFeld> {
  final TextEditingController _eingabe = TextEditingController();

  @override
  void dispose() {
    _eingabe.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    final adresse = _eingabe.text.trim();
    if (adresse.isEmpty) return;
    widget.onHinzufuegen(adresse);
    _eingabe.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vergeben = {
      for (final adresse in [...widget.adressen, ...widget.bereitsVergeben])
        adresse.toLowerCase(),
    };
    final offen = widget.vorschlaege
        .where(
          (vorschlag) => !vergeben.contains(vorschlag.adresse.toLowerCase()),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.titel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        if (widget.adressen.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final adresse in widget.adressen)
                InputChip(
                  label: Text(adresse),
                  onDeleted: widget.aktiv
                      ? () => widget.onEntfernen(adresse)
                      : null,
                ),
            ],
          ),
        if (widget.adressen.isNotEmpty) const SizedBox(height: 6),
        TextField(
          controller: _eingabe,
          enabled: widget.aktiv,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Adresse eintippen und mit Eingabe übernehmen',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Übernehmen',
              onPressed: widget.aktiv ? _uebernehmen : null,
              icon: const Icon(Icons.add),
            ),
          ),
          onSubmitted: (_) => _uebernehmen(),
        ),
        if (offen.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Bekannt zu diesem Vorgang:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final vorschlag in offen)
                ActionChip(
                  avatar: Icon(
                    vorschlag.art == EmpfaengerArt.mandant
                        ? Icons.person_outline
                        : Icons.business_outlined,
                    size: 18,
                  ),
                  label: Text(
                    '${vorschlag.bezeichnung} · ${vorschlag.adresse}',
                  ),
                  tooltip: vorschlag.herkunft,
                  onPressed: widget.aktiv
                      ? () => widget.onHinzufuegen(vorschlag.adresse)
                      : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
