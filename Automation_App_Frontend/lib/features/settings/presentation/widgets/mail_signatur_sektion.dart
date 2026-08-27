import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_aus_outlook_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Signatur unter dem Mailtext beim Direktversand (§4.7) — im Reiter
/// „E-Mail", bei dem Zugang, über den die Mail hinausgeht.
///
/// Sie liegt zwar im selben Einstellungssatz wie die Kanzleidaten, wird aber
/// **einzeln** gespeichert: Die beiden Formulare stehen in verschiedenen
/// Reitern, und ein Rundum-Speichern aus dem einen würde die ungespeicherten
/// Änderungen des anderen überschreiben.
class MailSignaturSektion extends StatefulWidget {
  const MailSignaturSektion({super.key});

  @override
  State<MailSignaturSektion> createState() => _MailSignaturSektionState();
}

class _MailSignaturSektionState extends State<MailSignaturSektion> {
  final TextEditingController _text = TextEditingController();

  /// Der Stand in der Datenbank. Weicht das Feld davon ab, gibt es etwas zu
  /// speichern — und nur dann ist der Knopf scharf.
  String _gespeichert = '';

  bool _geladen = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Übernimmt den geladenen Stand. Das Textfeld wird dabei nur **einmal**
  /// gesetzt: Speichert nebenan das Kanzleiformular, lädt der Bloc neu — was
  /// hier schon getippt ist, darf dabei nicht verschwinden.
  void _nachziehen(KanzleiSettings settings) {
    _gespeichert = settings.mailSignatur;
    if (!_geladen) {
      _geladen = true;
      _text.text = settings.mailSignatur;
    }
  }

  void _speichern() {
    context.read<KanzleiSettingsBloc>().add(
      SaveMailSignaturEvent(_text.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KanzleiSettingsBloc, KanzleiSettingsState>(
      listener: (context, state) {
        if (state is! KanzleiSettingsLoaded) return;
        setState(() => _nachziehen(state.settings));
        if (state.gespeichert == KanzleiSettingsBereich.signatur) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Signatur gespeichert')));
        }
      },
      builder: (context, state) {
        final speichertGerade = state is KanzleiSettingsLoading;

        return FormSection(
          icon: Icons.draw_outlined,
          title: 'E-Mail-Signatur',
          subtitle:
              'Steht unter dem Text jeder Mail, die die App selbst versendet. '
              'Wird die Mail stattdessen als Entwurf in Outlook geöffnet, '
              'setzt Outlook dort seine eigene ein.',
          children: [
            TextField(
              controller: _text,
              enabled: !speichertGerade,
              minLines: 4,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Signatur',
                alignLabelWithHint: true,
                hintText:
                    'Aus Outlook übernehmen oder hier von Hand eintragen.',
                border: OutlineInputBorder(),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _text,
              builder: (context, wert, _) {
                final geaendert = wert.text.trim() != _gespeichert.trim();
                return Row(
                  children: [
                    SignaturAusOutlookButton(
                      aktiv: !speichertGerade,
                      onUebernommen: (signatur) => setState(() {
                        _text.text = signatur.text;
                      }),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: geaendert && !speichertGerade
                          ? _speichern
                          : null,
                      icon: speichertGerade
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Signatur speichern'),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
