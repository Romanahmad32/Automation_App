import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_anhang_liste.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_bereitschaft_hinweis.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_empfaenger_feld.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Das Formular des Versanddialogs: Empfänger, Betreff, Text, Anhänge (§4.7).
/// Getrennt vom Dialog, damit dieser nur noch Rahmen und Schaltflächen ist.
class EmailVersandFormular extends StatefulWidget {
  /// Dateien aus dem Fall-Ordner des Vorgangs, zum Anklicken.
  final List<String> ausDerAkte;

  const EmailVersandFormular({super.key, this.ausDerAkte = const []});

  @override
  State<EmailVersandFormular> createState() => _EmailVersandFormularState();
}

class _EmailVersandFormularState extends State<EmailVersandFormular> {
  final TextEditingController _betreff = TextEditingController();
  final TextEditingController _text = TextEditingController();

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
        final aktiv = !state.beschaeftigt;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmailBereitschaftHinweis(
              bereitschaft: state.bereitschaft,
              fehler: state.fehler,
            ),
            const SizedBox(height: 16),
            EmailEmpfaengerFeld(
              titel: 'An',
              adressen: state.entwurf.an,
              vorschlaege: state.vorschlaege,
              bereitsVergeben: state.entwurf.alleEmpfaenger,
              onHinzufuegen: cubit.empfaengerHinzufuegen,
              onEntfernen: cubit.empfaengerEntfernen,
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
              aktiv: aktiv,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _betreff,
              enabled: aktiv,
              decoration: const InputDecoration(
                labelText: 'Betreff',
                border: OutlineInputBorder(),
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
            const SizedBox(height: 16),
            EmailAnhangListe(
              anhangPfade: state.entwurf.anhangPfade,
              ausDerAkte: widget.ausDerAkte,
              onHinzufuegen: cubit.anhangHinzufuegen,
              onEntfernen: cubit.anhangEntfernen,
              aktiv: aktiv,
            ),
          ],
        );
      },
    );
  }
}
