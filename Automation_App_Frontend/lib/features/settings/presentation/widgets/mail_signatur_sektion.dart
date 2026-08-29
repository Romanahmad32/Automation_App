import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/stand_nachziehen.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/outlook_hinweis_zeile.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_aus_outlook_button.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_format_zeile.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_render_vorschau.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Signatur unter dem Mailtext beim Direktversand (§4.7) — im Reiter
/// „E-Mail", bei dem Zugang, über den die Mail hinausgeht.
///
/// **Kein eigener Speichern-Knopf.** Sie hatte einen, weil sie in einem anderen
/// Einstellungssatz landet als die Postfachdaten daneben — eine Begründung aus
/// der Bauart, die auf dem Schirm nichts erklärte: Zwei Knöpfe „Speichern"
/// untereinander sahen aus wie zwei Formulare, und der obere stand mitten auf
/// der Seite, als gälte er für alles. Jetzt schreibt der eine Knopf der Seite
/// beides, jedes auf seinem Weg ([speichereWennGeaendert]).
class MailSignaturSektion extends StatefulWidget {
  /// Gehört der Seite, nicht diesem Abschnitt: Ihr Speichern-Knopf liest daraus.
  final TextEditingController controller;

  const MailSignaturSektion({super.key, required this.controller});

  /// Schreibt die Signatur, wenn sie vom gespeicherten Stand abweicht.
  ///
  /// Eigenes Ereignis und nicht Teil des Kanzlei-Formulars: Beide hängen am
  /// selben Einstellungssatz, stehen aber in verschiedenen Reitern — ein
  /// Rundum-Speichern aus dem einen überschriebe die ungespeicherten Änderungen
  /// des anderen.
  ///
  /// **Meldet nichts zurück.** Ob geschrieben wurde, weiß erst der Bloc:
  /// Er kopiert die Signatur in den zuletzt geladenen Einstellungssatz hinein
  /// und steigt ohne einen solchen wortlos wieder aus, und auch danach kann das
  /// Speichern noch scheitern. Der Abschnitt sagt deshalb selbst Bescheid,
  /// sobald der Bloc den Erfolg als [KanzleiSettingsBereich.signatur] meldet —
  /// vorher stand hier „Die Signatur ist gespeichert", während nichts
  /// geschrieben war.
  static void speichereWennGeaendert(BuildContext context, String signatur) {
    final bloc = context.read<KanzleiSettingsBloc>();
    final stand = bloc.state;
    if (stand is! KanzleiSettingsLoaded) return;

    final neu = signatur.trim();
    if (neu == stand.settings.mailSignatur.trim()) return;
    bloc.add(SaveMailSignaturEvent(neu));
  }

  @override
  State<MailSignaturSektion> createState() => _MailSignaturSektionState();
}

class _MailSignaturSektionState extends State<MailSignaturSektion> {
  bool _geladen = false;

  /// Was der Dienst gespeichert hat: formatierte Fassung ja/nein und ihre
  /// Bilder. Steht nicht im Einstellungssatz — die Bilder liegen im
  /// Dateisystem des Dienstes, und die HTML-Fassung geht bewusst nicht über
  /// die Leitung.
  SignaturStand _stand = const SignaturStand();

  /// Welches Outlook hier steht. Ohne das klassische gibt es nichts zu
  /// übernehmen — dann steht statt des Knopfes der Grund da.
  OutlookStand _outlook = OutlookStand.unbekannt;

  @override
  void initState() {
    super.initState();

    // Den vorhandenen Stand liest [StandNachziehen] unten — beim zweiten
    // Öffnen des Reiters steht der Bloc längst auf Loaded, und ein blosser
    // Listener feuerte nie.
    unawaited(_standLaden());
  }

  Future<void> _standLaden() async {
    try {
      final dienst = getIt<EmailVersandRepository>();
      final geladen = await (
        dienst.ladeSignaturStand(),
        dienst.ladeOutlookStand(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _stand = geladen.$1;
        _outlook = geladen.$2;
      });
    } catch (_) {
      // Ohne diese Auskunft fehlen nur die Zeile ueber dem Feld und die Bilder
      // in der Vorschau. Der Text darunter kommt aus den Einstellungen und
      // steht ohnehin.
    }
  }

  /// Nach einer Uebernahme steht in der Datenbank eine neue Signatur — auch
  /// die HTML-Fassung, die das Formular nur durchreicht. Ohne das Nachladen
  /// schriebe das naechste Speichern der Kanzleidaten die alte zurueck.
  void _uebernommen(SignaturStand stand) {
    setState(() {
      _stand = stand;
      widget.controller.text = stand.text;
    });
    context.read<KanzleiSettingsBloc>().add(const LoadKanzleiSettingsEvent());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_uebernahmeMeldung(stand)),
        duration: Duration(seconds: stand.uebergangen.isEmpty ? 4 : 8),
      ),
    );
  }

  /// Was übernommen wurde — und was nicht.
  ///
  /// Der zweite Teil ist der wichtigere: Ein Bild, das nicht mitgenommen
  /// werden konnte, fehlt danach in jeder Mail. Es wegzulassen **und** zu
  /// verschweigen, hiesse den Anwalt eine unvollständige Signatur führen zu
  /// lassen, ohne dass er es je erfährt.
  static String _uebernahmeMeldung(SignaturStand stand) {
    final grundstock = stand.hatFormat
        ? 'Signatur übernommen — mit Formatierung und '
              '${stand.bilder.length} Bild(ern).'
        : 'Signatur übernommen.';

    if (stand.uebergangen.isEmpty) return grundstock;

    final namen = stand.uebergangen.map(AnhangDarstellung.name).join(', ');
    return '$grundstock Nicht mitgenommen wurde $namen — zu groß, leer oder '
        'nicht lesbar. Die Signatur geht ohne dieses Bild hinaus.';
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
        melder.showSnackBar(
          SnackBar(content: Text('Fehlgeschlagen: ${ausnahmeText(e)}')),
        );
      }
    }
  }

  /// Übernimmt den geladenen Stand. Das Textfeld wird dabei nur **einmal**
  /// gesetzt: Speichert nebenan das Kanzleiformular, lädt der Bloc neu — was
  /// hier schon getippt ist, darf dabei nicht verschwinden.
  void _nachziehen(KanzleiSettings settings) {
    if (_geladen) return;
    _geladen = true;
    widget.controller.text = settings.mailSignatur;
  }

  @override
  Widget build(BuildContext context) {
    return StandNachziehen<KanzleiSettingsBloc, KanzleiSettingsState>(
      nachziehen: (context, state) {
        if (state is KanzleiSettingsLoaded) _nachziehen(state.settings);
      },
      beiUebergang: (context, state) {
        if (state is KanzleiSettingsLoaded &&
            state.gespeichert == KanzleiSettingsBereich.signatur) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Die Signatur ist gespeichert.')),
          );
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
              controller: widget.controller,
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
            Align(
              alignment: Alignment.centerLeft,
              child: _outlook.steuerbar
                  ? SignaturAusOutlookButton(
                      aktiv: !speichertGerade,
                      onUebernommen: _uebernommen,
                    )
                  : OutlookHinweisZeile(
                      stand: _outlook,
                      was:
                          'Die Signatur lässt sich nicht aus Outlook '
                          'übernehmen',
                    ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, wert, _) => SignaturRenderVorschau(
                text: wert.text,
                html: _stand.html,
                bilder: _stand.bilder,
              ),
            ),
          ],
        );
      },
    );
  }
}
