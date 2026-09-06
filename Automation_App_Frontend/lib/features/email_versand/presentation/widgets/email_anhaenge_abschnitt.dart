import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_anhang_liste.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_groesse_zeile.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_signatur_bilder.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/versand_abschnitt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der dritte Abschnitt des Versandformulars: **was mitgeht** (§4.7).
///
/// Anhänge, Signaturbilder und das Gewicht stehen zusammen, weil sie eine
/// Frage beantworten: Der Größenbalken zählt genau diese Posten, und wer die
/// Grenze reisst, entscheidet hier, was wegfällt. Vorher standen die drei über
/// das Formular verteilt, und der Balken hatte keinen erkennbaren Bezug.
class EmailAnhaengeAbschnitt extends StatelessWidget {
  final EmailEntwurfState state;

  /// Dateien aus dem Fall-Ordner des Vorgangs, zum Anklicken.
  final List<String> ausDerAkte;

  /// Fragt Outlook nach den Anhängen der offenen Nachricht — der Griff liegt
  /// im Formular darüber, weil er eine Rückmeldung zeigt.
  final VoidCallback onAusOutlook;

  final bool aktiv;

  const EmailAnhaengeAbschnitt({
    super.key,
    required this.state,
    required this.onAusOutlook,
    required this.aktiv,
    this.ausDerAkte = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EmailEntwurfCubit>();
    final signaturBilder = state.bereitschaft?.signaturBilder ?? const [];

    return VersandAbschnitt(
      symbol: Icons.attach_file,
      titel: 'Anhänge',
      untertitel:
          'Dateien lassen sich auch aus dem Explorer auf den Dialog ziehen.',
      children: [
        EmailAnhangListe(
          anhangPfade: state.entwurf.anhangPfade,
          namen: state.entwurf.anhangNamen,
          ausDerAkte: ausDerAkte,
          ausOutlook: state.ausOutlook,
          onHinzufuegen: cubit.anhangHinzufuegen,
          onEntfernen: cubit.anhangEntfernen,
          onUmbenennen: cubit.anhangUmbenennen,
          outlookQuelle: state.outlookQuelle,
          outlookStand: state.outlookStand,
          onAusOutlook: onAusOutlook,
          onOutlookVerwerfen: cubit.outlookAnhangVerwerfen,
          holtAusOutlook: state.holtAusOutlook,
          aktiv: aktiv,
        ),
        if (signaturBilder.isNotEmpty) ...[
          const SizedBox(height: 16),
          EmailSignaturBilder(
            bilder: signaturBilder,
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
  }
}
