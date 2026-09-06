import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_empfaenger_feld.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/versand_abschnitt.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorgang_auswahl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der erste Abschnitt des Versandformulars: **Wer bekommt die Mail** (§4.7).
///
/// Der Vorgang steht mit darin und nicht darüber: Aus ihm kommen die
/// Vorschläge in beiden Zeilen — Mandant und Versicherung —, und wer ihn
/// wechselt, bekommt andere Empfänger. Die Frage „an wen" fängt bei ihm an.
class EmailEmpfaengerAbschnitt extends StatelessWidget {
  final EmailEntwurfState state;
  final bool aktiv;

  const EmailEmpfaengerAbschnitt({
    super.key,
    required this.state,
    required this.aktiv,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EmailEntwurfCubit>();

    return VersandAbschnitt(
      symbol: Icons.group_outlined,
      titel: 'Empfänger',
      untertitel:
          'Der Vorgang belegt Empfänger, Betreff und Text vor — deshalb steht '
          'er vor den Feldern.',
      children: [
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
      ],
    );
  }
}
