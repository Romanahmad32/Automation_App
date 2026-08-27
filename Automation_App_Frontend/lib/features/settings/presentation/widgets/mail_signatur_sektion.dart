import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_aus_outlook_button.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_format_zeile.dart';
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

  /// Was der Dienst gespeichert hat: formatierte Fassung ja/nein und ihre
  /// Bilder. Steht nicht im Einstellungssatz — die Bilder liegen im
  /// Dateisystem des Dienstes, und die HTML-Fassung geht bewusst nicht über
  /// die Leitung.
  SignaturStand _stand = const SignaturStand();

  @override
  void initState() {
    super.initState();
    unawaited(_standLaden());
  }

  Future<void> _standLaden() async {
    try {
      final geladen = await getIt<EmailVersandRepository>().ladeSignaturStand();
      if (mounted) setState(() => _stand = geladen);
    } catch (_) {
      // Ohne diese Auskunft fehlt nur die Zeile ueber dem Feld. Der Text
      // darunter kommt aus den Einstellungen und steht ohnehin.
    }
  }

  /// Nach einer Uebernahme steht in der Datenbank eine neue Signatur — auch
  /// die HTML-Fassung, die das Formular nur durchreicht. Ohne das Nachladen
  /// schriebe das naechste Speichern der Kanzleidaten die alte zurueck.
  void _uebernommen(SignaturStand stand) {
    setState(() {
      _stand = stand;
      _gespeichert = stand.text;
      _text.text = stand.text;
    });
    context.read<KanzleiSettingsBloc>().add(const LoadKanzleiSettingsEvent());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stand.hatFormat
              ? 'Signatur übernommen — mit Formatierung und '
                    '${stand.bilder.length} Bild(ern).'
              : 'Signatur übernommen.',
        ),
      ),
    );
  }

  Future<void> _formatVerwerfen() async {
    final melder = ScaffoldMessenger.of(context);
    final bloc = context.read<KanzleiSettingsBloc>();
    try {
      final stand = await getIt<EmailVersandRepository>()
          .verwirfSignaturFormat();
      if (!mounted) return;
      setState(() => _stand = stand);
      bloc.add(const LoadKanzleiSettingsEvent());
      melder.showSnackBar(
        const SnackBar(
          content: Text('Die Formatierung ist weg — der Text bleibt.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        melder.showSnackBar(SnackBar(content: Text('Fehlgeschlagen: $e')));
      }
    }
  }

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
              'Steht unter dem Text jeder Mail, die die App selbst versendet — '
              'mit Schrift, Farben und Bildern, wenn Outlook sie so führt. '
              'Wird die Mail stattdessen als Entwurf in Outlook geöffnet, '
              'setzt Outlook dort seine eigene ein.',
          children: [
            SignaturFormatZeile(
              stand: _stand,
              onVerwerfen: _formatVerwerfen,
              aktiv: !speichertGerade,
            ),
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
                      onUebernommen: _uebernommen,
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
