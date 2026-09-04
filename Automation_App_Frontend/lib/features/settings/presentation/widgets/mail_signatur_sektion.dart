import 'dart:async';

import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/stand_nachziehen.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/entities/signatur_stand.dart';
import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_format_zeile.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_knopfzeile.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_render_vorschau.dart';
import 'package:automation_app/features/settings/presentation/widgets/signatur_vorgemerkt_zeile.dart';
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
///
/// **Und der Import schreibt nicht mehr selbst** (geändert am 02.09.2026): Wer
/// eine Signatur aus Outlook wählte, hatte sie damit schon gewechselt — samt
/// gelöschter Bilder der bisherigen, ohne je auf „Speichern" gedrückt zu haben.
/// Jetzt füllt der Import nur das Formular und merkt den Namen vor
/// ([vorgemerkt]); übernommen wird beim Speichern.
class MailSignaturSektion extends StatefulWidget {
  /// Gehört der Seite, nicht diesem Abschnitt: Ihr Speichern-Knopf liest daraus.
  final TextEditingController controller;

  /// Name der aus Outlook **gelesenen, noch nicht übernommenen** Signatur;
  /// leer heißt: keine vorgemerkt.
  ///
  /// Gehört ebenfalls der Seite, und aus demselben Grund: Ihr Speichern-Knopf
  /// muss die Übernahme auslösen, und er kennt diesen Abschnitt nur über das,
  /// was ihm mitgegeben wird.
  final ValueNotifier<String> vorgemerkt;

  const MailSignaturSektion({
    super.key,
    required this.controller,
    required this.vorgemerkt,
  });

  /// Schreibt die Signatur: erst eine vorgemerkte Übernahme aus Outlook, dann
  /// den Text aus dem Feld.
  ///
  /// **Die Reihenfolge ist die Regel.** Die Übernahme schreibt Outlooks
  /// Nur-Text-Fassung mit; was der Anwalt danach von Hand geändert hat, muss
  /// darüber gewinnen. Andersherum stünde nach dem Speichern wieder Outlooks
  /// Fassung im Feld.
  ///
  /// Eigenes Ereignis und nicht Teil des Kanzlei-Formulars: Beide hängen am
  /// selben Einstellungssatz, stehen aber in verschiedenen Reitern — ein
  /// Rundum-Speichern aus dem einen überschriebe die ungespeicherten Änderungen
  /// des anderen.
  ///
  /// **Meldet den Erfolg nicht selbst.** Ob geschrieben wurde, weiß erst der
  /// Bloc: Er kopiert die Signatur in den zuletzt geladenen Einstellungssatz
  /// hinein und steigt ohne einen solchen wortlos wieder aus. Der Abschnitt
  /// sagt deshalb Bescheid, sobald der Bloc den Erfolg als
  /// [KanzleiSettingsBereich.signatur] meldet. Nur das Misslingen der
  /// **Übernahme** steht hier: Danach ist nichts geschrieben, und der Bloc
  /// erfährt davon nichts.
  static Future<void> speichereWennGeaendert(
    BuildContext context,
    String signatur,
    ValueNotifier<String> vorgemerkt,
  ) async {
    final bloc = context.read<KanzleiSettingsBloc>();
    final melder = Rueckmeldung.von(context);
    final stand = bloc.state;
    if (stand is! KanzleiSettingsLoaded) return;

    final name = vorgemerkt.value;
    if (name.isNotEmpty) {
      try {
        await getIt<EmailVersandRepository>().uebernimmSignatur(name);
        // Nach dem await kann die Seite weg sein — der Aufrufer schickt diese
        // Methode ohne `await` los (`unawaited`), und `vorgemerkt` gehört
        // ihm: Nach seinem `dispose` wäre das Schreiben ein Zugriff auf einen
        // entsorgten `ValueNotifier`, der Bloc daneben womöglich geschlossen
        // (behoben am 02.09.2026). Verloren ist dabei nichts: Die Übernahme
        // ist durch und hat die Nur-Text-Fassung mitgeschrieben — nur was der
        // Anwalt danach von Hand geändert hat, bleibt ungespeichert.
        if (!context.mounted) return;
        vorgemerkt.value = '';
      } catch (e) {
        if (!context.mounted) return;
        melder.fehler(
          'Die Signatur ließ sich nicht übernehmen: ${ausnahmeText(e)}',
        );
        return;
      }
    }

    final neu = signatur.trim();
    // Nach einer Übernahme immer schreiben: Sie hat den Text schon angefasst,
    // und der aus dem Feld ist der maßgebliche.
    if (name.isEmpty && neu == stand.settings.mailSignatur.trim()) return;
    bloc.add(SaveMailSignaturEvent(neu));
  }

  @override
  State<MailSignaturSektion> createState() => _MailSignaturSektionState();
}

class _MailSignaturSektionState extends State<MailSignaturSektion> {
  bool _geladen = false;

  /// Was der Dienst hält, oder — bei vorgemerkter Übernahme — was aus Outlook
  /// gelesen wurde: formatierte Fassung ja/nein und ihre Bilder. Steht nicht
  /// im Einstellungssatz — die Bilder liegen im Dateisystem des Dienstes.
  SignaturStand _stand = const SignaturStand();

  /// Welches Outlook hier steht. Ohne das klassische gibt es nichts zu
  /// übernehmen — dann steht statt des Knopfes der Grund da.
  OutlookStand _outlook = OutlookStand.unbekannt;

  @override
  void initState() {
    super.initState();
    widget.vorgemerkt.addListener(_vorgemerktGeaendert);

    // Den vorhandenen Stand liest [StandNachziehen] unten — beim zweiten
    // Öffnen des Reiters steht der Bloc längst auf Loaded, und ein blosser
    // Listener feuerte nie.
    unawaited(_standLaden());
  }

  @override
  void dispose() {
    widget.vorgemerkt.removeListener(_vorgemerktGeaendert);
    super.dispose();
  }

  /// Fällt der vorgemerkte Name weg, ist die Übernahme durch — jetzt liegen
  /// die Bilder im Dienst, und die Vorschau holt sie von dort statt aus
  /// Outlook.
  void _vorgemerktGeaendert() {
    if (widget.vorgemerkt.value.isEmpty) unawaited(_standLaden());
    if (mounted) setState(() {});
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
        // Eine vorgemerkte Übernahme steht über dem gespeicherten Stand: Sie
        // ist es, die der Anwalt gerade ansieht.
        if (widget.vorgemerkt.value.isEmpty) _stand = geladen.$1;
        _outlook = geladen.$2;
      });
    } catch (_) {
      // Ohne diese Auskunft fehlen nur die Zeile ueber dem Feld und die Bilder
      // in der Vorschau. Der Text darunter kommt aus den Einstellungen und
      // steht ohnehin.
    }
  }

  /// Der Import: Formular füllen, Namen vormerken — **nicht** speichern.
  void _gelesen(String name, SignaturStand stand) {
    setState(() {
      _stand = stand;
      widget.controller.text = stand.text;
    });
    widget.vorgemerkt.value = name;
    Rueckmeldung.zeigeHinweis(
      context,
      _leseMeldung(stand),
      dauer: Duration(seconds: stand.uebergangen.isEmpty ? 5 : 9),
    );
  }

  /// Was gelesen wurde — und was nicht.
  ///
  /// Der zweite Teil ist der wichtigere: Ein Bild, das nicht mitgenommen
  /// werden kann, fehlt danach in jeder Mail. Es wegzulassen **und** zu
  /// verschweigen, hiesse den Anwalt eine unvollständige Signatur führen zu
  /// lassen, ohne dass er es je erfährt.
  static String _leseMeldung(SignaturStand stand) {
    final grundstock = stand.hatFormat
        ? 'Signatur gelesen — mit Formatierung und '
              '${stand.bilder.length} Bild(ern). Zum Speichern unten klicken.'
        : 'Signatur gelesen. Zum Speichern unten klicken.';

    if (stand.uebergangen.isEmpty) return grundstock;

    final namen = stand.uebergangen.map(AnhangDarstellung.name).join(', ');
    return '$grundstock Nicht mitgenommen wird $namen — zu groß, leer oder '
        'nicht lesbar. Die Signatur geht ohne dieses Bild hinaus.';
  }

  Future<void> _formatVerwerfen() async {
    final melder = Rueckmeldung.von(context);
    final bloc = context.read<KanzleiSettingsBloc>();
    try {
      final stand = await getIt<EmailVersandRepository>()
          .verwirfSignaturFormat();
      if (!mounted) return;
      setState(() => _stand = stand);
      widget.vorgemerkt.value = '';
      bloc.add(const LoadKanzleiSettingsEvent());
      melder.hinweis('Die Formatierung ist weg — der Text bleibt.');
    } catch (e) {
      if (mounted) {
        melder.fehler('Fehlgeschlagen: ${ausnahmeText(e)}');
      }
    }
  }

  /// Entfernt die Signatur ganz: Formatierung und Bilder im Dienst, Text in
  /// den Einstellungen (§4.7).
  ///
  /// **Beides, und das war der Mangel.** Das Feld zu leeren und zu speichern
  /// entfernte nur die Nur-Text-Fassung; die HTML-Fassung blieb stehen, und
  /// weil die Mail sie bevorzugt, ging die Signatur samt Logo weiter hinaus.
  Future<void> _entfernen() async {
    final melder = Rueckmeldung.von(context);
    final bloc = context.read<KanzleiSettingsBloc>();
    try {
      await getIt<EmailVersandRepository>().verwirfSignaturFormat();
      if (!mounted) return;
      setState(() {
        _stand = const SignaturStand();
        widget.controller.clear();
      });
      widget.vorgemerkt.value = '';
      bloc.add(const SaveMailSignaturEvent(''));
    } catch (e) {
      if (mounted) {
        melder.fehler('Fehlgeschlagen: ${ausnahmeText(e)}');
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
          Rueckmeldung.zeigeErfolg(context, 'Die Signatur ist gespeichert.');
        }
      },
      builder: (context, state) {
        final speichertGerade = state is KanzleiSettingsLoading;
        final vorgemerkt = widget.vorgemerkt.value;

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
            if (vorgemerkt.isNotEmpty)
              SignaturVorgemerktZeile(name: vorgemerkt),
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
            SignaturKnopfzeile(
              outlook: _outlook,
              aktiv: !speichertGerade,
              onGelesen: _gelesen,
              onEntfernen: _entfernen,
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, wert, _) => SignaturRenderVorschau(
                text: wert.text,
                html: _stand.html,
                bilder: _stand.bilder,
                // Solange eine Übernahme aussteht, liegen deren Bilder noch
                // nicht in der Ablage — sie kommen aus Outlook.
                ausOutlook: vorgemerkt,
              ),
            ),
          ],
        );
      },
    );
  }
}
