import 'dart:math' as math;

import 'package:automation_app/core/general_widgets/datei_ablage_bereich.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/email_versand/presentation/utils/outlook_griff_meldung.dart';
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
    final schonDran = cubit.state.entwurf.anhangPfade.toSet();
    for (final pfad in pfade) {
      cubit.anhangHinzufuegen(pfad);
    }

    // Ein zweites Ablegen derselben Datei haengt sie nicht doppelt an
    // (`mitAnhang` prueft den Pfad). Ohne diesen Satz sieht das aber aus wie
    // ein verschluckter Griff.
    if (pfade.any((pfad) => !schonDran.contains(pfad))) return;
    _melden(context, 'Diese Dateien hängen bereits an der Mail.');
  }

  /// Ein Ablegen, bei dem Windows keine einzige Datei durchgereicht hat — fast
  /// immer ein Anhang, der aus einer Outlook-Nachricht gezogen wurde.
  ///
  /// Outlook gibt seine Anhänge nicht als Dateien heraus, sondern als
  /// virtuelle Dateien, die erst beim Ablegen erzeugt werden; die App bekommt
  /// davon nichts. Statt den Griff verpuffen zu lassen, fragt sie Outlook nach
  /// den Anhängen genau der Nachricht, aus der gezogen wurde — es ist dieselbe,
  /// die dort offen oder markiert ist. Angehängt wird nichts von selbst: Die
  /// Dateien liegen danach als Vorschläge in der Reihe, einer davon der
  /// gezogene.
  Future<void> _nichtsErkannt(BuildContext context) async {
    final melder = Rueckmeldung.von(context);
    final cubit = context.read<EmailEntwurfCubit>();
    final ergebnis = await cubit.anhaengeAusOutlook();

    if (ergebnis == null) {
      melder.hinweis(
        'Diese Datei hat Windows nicht als Datei durchgereicht — aus Outlook '
        'gezogene Anhänge kommen so nicht an. Der Knopf „Aus der '
        'Outlook-Nachricht" holt sie.',
        dauer: const Duration(seconds: 6),
      );
      return;
    }

    melder.hinweis(
      OutlookGriffMeldung.fuer(
            ergebnis.griff,
            ergebnis.neu,
            vorspann: 'Outlook gibt gezogene Anhänge nicht als Datei heraus.',
          ) ??
          'Outlook gibt gezogene Anhänge nicht als Datei heraus — die Anhänge '
              'von ${ergebnis.griff.bezeichnung} liegen jetzt unten zum '
              'Anklicken bereit.',
      dauer: const Duration(seconds: 6),
    );
  }

  static void _melden(BuildContext context, String text) {
    Rueckmeldung.zeigeHinweis(context, text);
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
      onOrdnerAbgelehnt: () => _melden(
        context,
        'Ordner lassen sich nicht anhängen — bitte die einzelnen Dateien ablegen.',
      ),
      onNichtsErkannt: () => _nichtsErkannt(context),
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
                      signaturHtml: state.bereitschaft?.signaturHtml ?? '',
                      signaturBilder:
                          state.bereitschaft?.signaturBilder ?? const [],
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(child: formular),
      ),
    );
  }
}
