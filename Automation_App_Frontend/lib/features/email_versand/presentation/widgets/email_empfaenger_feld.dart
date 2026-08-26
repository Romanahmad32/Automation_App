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

  /// Meldet, was gerade im Eingabefeld steht und noch **nicht** übernommen ist.
  /// Der Dialog kann daraufhin sagen, warum „Senden" grau bleibt — eine
  /// eingetippte, aber nicht übernommene Adresse ist der Fall, in dem das Feld
  /// ausgefüllt aussieht und der Entwurf trotzdem keinen Empfänger hat.
  final ValueChanged<String>? onOffeneEingabe;

  final bool aktiv;

  const EmailEmpfaengerFeld({
    super.key,
    required this.titel,
    required this.adressen,
    required this.onHinzufuegen,
    required this.onEntfernen,
    this.vorschlaege = const [],
    this.bereitsVergeben = const [],
    this.onOffeneEingabe,
    this.aktiv = true,
  });

  @override
  State<EmailEmpfaengerFeld> createState() => _EmailEmpfaengerFeldState();
}

class _EmailEmpfaengerFeldState extends State<EmailEmpfaengerFeld> {
  final TextEditingController _eingabe = TextEditingController();
  final FocusNode _fokus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Wer weiterklickt, ohne Eingabe zu druecken, hat die Adresse gemeint.
    // Sie hier verfallen zu lassen, waere die unfreundlichste Auslegung.
    _fokus.addListener(() {
      if (!_fokus.hasFocus) _uebernehmen();
    });
  }

  @override
  void dispose() {
    _fokus.dispose();
    _eingabe.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    final adresse = _eingabe.text.trim();
    if (adresse.isEmpty) return;
    widget.onHinzufuegen(adresse);
    _eingabe.clear();
    widget.onOffeneEingabe?.call('');
  }

  /// Komma und Semikolon trennen Adressen — in jedem Mailprogramm. Wer sie
  /// tippt, hat die vorige fertig geschrieben.
  void _getippt(String text) {
    if (text.endsWith(',') || text.endsWith(';')) {
      _eingabe.text = text.substring(0, text.length - 1);
      _uebernehmen();
      return;
    }

    widget.onOffeneEingabe?.call(text);
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
          focusNode: _fokus,
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
          onChanged: _getippt,
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
