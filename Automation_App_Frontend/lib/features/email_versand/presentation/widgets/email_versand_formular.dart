import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/utils/outlook_griff_meldung.dart';
import 'package:automation_app/features/email_versand/presentation/utils/platzhalter_einfuege_ziel.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_anhaenge_abschnitt.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_bereitschaft_hinweis.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_empfaenger_abschnitt.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_hinweis_kasten.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_inhalt_abschnitt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Das Formular des Versanddialogs — **drei benannte Abschnitte** statt
/// fünfzehn Blöcken untereinander: Empfänger, Inhalt, Anhänge (§4.7, neu
/// geordnet am 06.09.2026).
///
/// Diese Datei hält nur noch zusammen, was die drei Abschnitte gemeinsam
/// brauchen: die zwei Textfelder samt Einfügeziel (sie müssen jeden Neubau
/// überleben, sonst springt die Schreibmarke) und die Meldungen, die über allen
/// dreien stehen.
class EmailVersandFormular extends StatefulWidget {
  /// Dateien aus dem Fall-Ordner des Vorgangs, zum Anklicken.
  final List<String> ausDerAkte;

  /// Zeigt die hinterlegte Signatur unter dem Nachrichtenfeld. Aus, sobald die
  /// Vorschau daneben steht — dort ist sie ohnehin im vollen Text zu sehen.
  final bool mitSignaturVorschau;

  const EmailVersandFormular({
    super.key,
    this.ausDerAkte = const [],
    this.mitSignaturVorschau = true,
  });

  @override
  State<EmailVersandFormular> createState() => _EmailVersandFormularState();
}

class _EmailVersandFormularState extends State<EmailVersandFormular> {
  final TextEditingController _betreff = TextEditingController();
  final TextEditingController _text = TextEditingController();

  /// Welches der beiden Felder ein Platzhalter-Klick trifft — und der Weg,
  /// ihn einzusetzen. Die zwei Rückrufe sind nötig, weil ein programmatisch
  /// gesetzter Controllerwert **kein** `onChanged` auslöst: Ohne sie landete
  /// der eingefügte Name im Feld und nie im Entwurf.
  late final PlatzhalterEinfuegeZiel _ziel;

  /// Fragt Outlook nach den Anhaengen der offenen Nachricht und sagt, was
  /// dabei herauskam — „nichts gefunden" ist eine Antwort, kein Ausbleiben.
  Future<void> _ausOutlook(
    BuildContext context,
    EmailEntwurfCubit cubit,
  ) async {
    final melder = Rueckmeldung.von(context);
    final ergebnis = await cubit.anhaengeAusOutlook();
    if (!mounted || ergebnis == null) return;

    final meldung = OutlookGriffMeldung.fuer(ergebnis.griff, ergebnis.neu);
    if (meldung == null) return;
    melder.hinweis(meldung);
  }

  @override
  void initState() {
    super.initState();
    final cubit = context.read<EmailEntwurfCubit>();
    _betreff.text = cubit.state.entwurf.betreff;
    _text.text = cubit.state.entwurf.text;
    _ziel = PlatzhalterEinfuegeZiel(
      betreff: _betreff,
      text: _text,
      onBetreffGeaendert: cubit.setzeBetreff,
      onTextGeaendert: cubit.setzeText,
    );
  }

  @override
  void dispose() {
    _ziel.dispose();
    _betreff.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EmailEntwurfCubit>();

    return BlocConsumer<EmailEntwurfCubit, EmailEntwurfState>(
      // Nur nachziehen, wenn der Entwurf sich anderswo geändert hat — etwa
      // weil die Anrede einem neuen Empfänger gefolgt ist. Beim Tippen sind
      // Feld und Zustand ohnehin gleich, dann bleibt der Cursor stehen.
      listenWhen: (vorher, jetzt) =>
          vorher.entwurf.betreff != jetzt.entwurf.betreff ||
          vorher.entwurf.text != jetzt.entwurf.text,
      listener: (context, state) {
        if (_betreff.text != state.entwurf.betreff) {
          _betreff.text = state.entwurf.betreff;
        }
        if (_text.text != state.entwurf.text) {
          _text.text = state.entwurf.text;
        }
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final aktiv = !state.beschaeftigt;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmailBereitschaftHinweis(
              bereitschaft: state.bereitschaft,
              fehler: state.fehler,
            ),
            if (state.entwurfErgebnis case final uebergeben?) ...[
              const SizedBox(height: 8),
              EmailHinweisKasten(
                farbe: theme.colorScheme.secondaryContainer,
                vordergrund: theme.colorScheme.onSecondaryContainer,
                symbol: Icons.mark_email_read_outlined,
                text:
                    uebergeben.hinweis ??
                    'Der Entwurf liegt in Outlook — dort gesendet, gilt er als '
                        'außerhalb der App versendet. Das Häkchen beim '
                        'Abschluss setzen Sie von Hand.',
              ),
            ],
            const SizedBox(height: 16),
            EmailEmpfaengerAbschnitt(state: state, aktiv: aktiv),
            EmailInhaltAbschnitt(
              state: state,
              ziel: _ziel,
              aktiv: aktiv,
              mitSignaturVorschau: widget.mitSignaturVorschau,
            ),
            EmailAnhaengeAbschnitt(
              state: state,
              ausDerAkte: widget.ausDerAkte,
              onAusOutlook: () => _ausOutlook(context, cubit),
              aktiv: aktiv,
            ),
          ],
        );
      },
    );
  }
}
