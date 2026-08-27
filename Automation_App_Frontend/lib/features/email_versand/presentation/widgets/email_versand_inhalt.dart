import 'dart:math' as math;

import 'package:automation_app/core/general_widgets/datei_ablage_bereich.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_versand_formular.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/email_vorschau_spalte.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Rumpf des Versanddialogs: Formular, daneben — wenn das Fenster es
/// hergibt — die mitlaufende Vorschau, und über allem der Bereich, auf dem
/// sich Dateien aus dem Explorer ablegen lassen (§4.7).
///
/// Eigene Datei, damit der Dialog daneben nur noch Rahmen und Schaltflächen
/// ist.
class EmailVersandInhalt extends StatelessWidget {
  /// Ab dieser Fensterbreite steht die Vorschau dauerhaft neben dem Formular.
  /// Darunter bleibt sie hinter dem Knopf: Zwei Spalten auf einem 1366er
  /// Laptop nützen weder dem Formular noch der Vorschau.
  static const double zweiSpaltenAb = 1180;

  static bool zweispaltig(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= zweiSpaltenAb;

  final EmailEntwurfState state;

  /// Dateien aus dem Fall-Ordner des Vorgangs, zum Anklicken.
  final List<String> ausDerAkte;

  const EmailVersandInhalt({
    super.key,
    required this.state,
    this.ausDerAkte = const [],
  });

  void _abgelegt(BuildContext context, List<String> pfade) {
    final cubit = context.read<EmailEntwurfCubit>();
    for (final pfad in pfade) {
      cubit.anhangHinzufuegen(pfad);
    }
  }

  void _nurOrdner(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ordner lassen sich nicht anhängen — bitte die einzelnen Dateien '
          'ablegen.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fenster = MediaQuery.sizeOf(context);
    final nebeneinander = zweispaltig(context);
    final formular = EmailVersandFormular(
      ausDerAkte: ausDerAkte,
      // Nebenan steht die Signatur schon im vollen Text; zweimal dasselbe
      // unter dem Nachrichtenfeld wäre nur Lärm.
      mitSignaturVorschau: !nebeneinander,
    );

    return DateiAblageBereich(
      aktiv: !state.beschaeftigt,
      hinweis: 'Loslassen, um die Dateien anzuhängen',
      onDateien: (pfade) => _abgelegt(context, pfade),
      onOrdnerAbgelehnt: () => _nurOrdner(context),
      child: SizedBox(
        width: math.min(nebeneinander ? 1160 : 720, fenster.width - 120),
        // Zwei Spalten brauchen eine begrenzte Höhe, sonst hat die Vorschau
        // nichts, worin sie sich ausdehnen könnte.
        height: nebeneinander ? math.min(660, fenster.height - 220) : null,
        child: nebeneinander
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(child: formular),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: EmailVorschauSpalte(
                      entwurf: state.entwurf,
                      absender: state.bereitschaft?.absender ?? '',
                      signatur: state.bereitschaft?.signatur ?? '',
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(child: formular),
      ),
    );
  }
}
