import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anrede_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_anhang_liste.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_bereitschaft_hinweis.dart';
import 'package:automation_app/features/email_versand/presentation/utils/outlook_griff_meldung.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_empfaenger_feld.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/geschlecht_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/handarbeit_hinweis.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_groesse_zeile.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_hinweis_kasten.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_signatur_bilder.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_signatur_vorschau.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/grussformel_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/mail_vorlagen_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_uebersicht.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorgang_auswahl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Das Formular des Versanddialogs: Empfänger, Betreff, Text, Anhänge (§4.7).
/// Getrennt vom Dialog, damit dieser nur noch Rahmen und Schaltflächen ist.
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

  /// Fragt Outlook nach den Anhaengen der offenen Nachricht und sagt, was
  /// dabei herauskam — „nichts gefunden" ist eine Antwort, kein Ausbleiben.
  Future<void> _ausOutlook(
    BuildContext context,
    EmailEntwurfCubit cubit,
  ) async {
    final melder = ScaffoldMessenger.of(context);
    final ergebnis = await cubit.anhaengeAusOutlook();
    if (!mounted || ergebnis == null) return;

    final meldung = OutlookGriffMeldung.fuer(ergebnis.griff, ergebnis.neu);
    if (meldung == null) return;
    melder.showSnackBar(SnackBar(content: Text(meldung)));
  }

  @override
  void initState() {
    super.initState();
    final entwurf = context.read<EmailEntwurfCubit>().state.entwurf;
    _betreff.text = entwurf.betreff;
    _text.text = entwurf.text;
  }

  @override
  void dispose() {
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
            // Ganz oben, weil alles Weitere daraus vorbelegt wird (§4.7): Wer
            // den Vorgang erst nach dem Tippen wechselt, bekommt Empfänger und
            // Betreff neu — deshalb steht die Frage vor den Feldern.
            const VorgangAuswahl(),
            EmailEmpfaengerFeld(
              titel: 'An',
              adressen: state.entwurf.an,
              vorschlaege: state.vorschlaege,
              bereitsVergeben: state.entwurf.alleEmpfaenger,
              onHinzufuegen: cubit.empfaengerHinzufuegen,
              onEntfernen: cubit.empfaengerEntfernen,
              onOffeneEingabe: (text) => cubit.setzeOffeneEingabe(an: text),
              fehler: state.markiert.anFehler,
              aktiv: aktiv,
            ),
            const SizedBox(height: 16),
            EmailEmpfaengerFeld(
              titel: 'Kopie (CC)',
              adressen: state.entwurf.kopie,
              vorschlaege: state.vorschlaege,
              bereitsVergeben: state.entwurf.alleEmpfaenger,
              onHinzufuegen: cubit.kopieHinzufuegen,
              onEntfernen: cubit.empfaengerEntfernen,
              onOffeneEingabe: (text) => cubit.setzeOffeneEingabe(kopie: text),
              fehler: state.markiert.kopieFehler,
              aktiv: aktiv,
            ),
            const SizedBox(height: 16),
            // Ueber den Chipreihen, weil er von ihnen handelt: Was sie noch
            // tun, sobald der Text von Hand bearbeitet ist (§4.7).
            const HandarbeitHinweis(),
            const MailVorlagenAuswahl(),
            // Anredeart vor Anrede vor Gruss: Die erste beugt die zweite, und
            // die zweite steht in der Mail ueber der dritten.
            const GeschlechtAuswahl(),
            const AnredeAuswahl(),
            const GrussformelAuswahl(),
            const PlatzhalterUebersicht(),
            TextField(
              controller: _betreff,
              enabled: aktiv,
              decoration: InputDecoration(
                labelText: 'Betreff',
                border: const OutlineInputBorder(),
                errorText: state.markiert.betreffFehler,
                isDense: true,
              ),
              onChanged: cubit.setzeBetreff,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _text,
              enabled: aktiv,
              minLines: 8,
              maxLines: 16,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: 'Nachricht',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              onChanged: cubit.setzeText,
            ),
            if (widget.mitSignaturVorschau)
              EmailSignaturVorschau(
                signatur: state.bereitschaft?.signatur ?? '',
                html: state.bereitschaft?.signaturHtml ?? '',
                bilder: state.bereitschaft?.signaturBilder ?? const [],
                weggelassen: state.entwurf.ohneSignaturBilder,
              ),
            const SizedBox(height: 16),
            EmailAnhangListe(
              anhangPfade: state.entwurf.anhangPfade,
              namen: state.entwurf.anhangNamen,
              ausDerAkte: widget.ausDerAkte,
              ausOutlook: state.ausOutlook,
              onHinzufuegen: cubit.anhangHinzufuegen,
              onEntfernen: cubit.anhangEntfernen,
              onUmbenennen: cubit.anhangUmbenennen,
              outlookQuelle: state.outlookQuelle,
              outlookStand: state.outlookStand,
              onAusOutlook: () => _ausOutlook(context, cubit),
              onOutlookVerwerfen: cubit.outlookAnhangVerwerfen,
              holtAusOutlook: state.holtAusOutlook,
              aktiv: aktiv,
            ),
            if (state.bereitschaft?.signaturBilder.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              EmailSignaturBilder(
                bilder: state.bereitschaft!.signaturBilder,
                weggelassen: state.entwurf.ohneSignaturBilder,
                onUmschalten: cubit.signaturBildUmschalten,
                aktiv: aktiv,
              ),
            ],
            EmailGroesseZeile(
              gesamtBytes: state.gesamtBytes,
              maxBytes: state.bereitschaft?.maxBytes,
            ),
          ],
        );
      },
    );
  }
}
