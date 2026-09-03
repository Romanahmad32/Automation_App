import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart';
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_daten.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_aenderung.dart';
import 'package:automation_app/features/vorgang_starten/presentation/widgets/mandant_uebersicht_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Button am Ende der Mandanten-Karte: erst aktiv, wenn ein bestehender Mandant
/// geänderte Daten hat („Mandantendaten aktualisieren") oder ohne Auswahl das
/// Mindeste für einen neuen Mandanten erfasst ist („Neuen Mandanten speichern").
/// Öffnet vor dem Speichern die Übersicht zur Bestätigung (§1.3) und meldet die
/// bestätigte Aktion über [onBestaetigt]; speichert nur den Mandanten, nicht den
/// Vorgang.
///
/// Solange etwas zu speichern ist, steht er als gefüllter Knopf da, sonst als
/// umrandeter: Er ist der einzige Schritt des Formulars, dessen Vergessen Daten
/// kostet, und ein bloß *aktiver* Knopf sagt das niemandem. Die Zeile darüber
/// (`MandantUngespeichertHinweis`) und der Rand der Karte hängen an derselben
/// Bedingung — deshalb kommt [art] von der Karte und wird nicht hier ein
/// zweites Mal aus dem Formular abgeleitet.
class MandantSpeichernButton extends StatelessWidget {
  /// Was ein Klick bewirken würde: nichts, anlegen oder aktualisieren.
  final MandantAenderungsart art;

  /// Die Eingaben, aus denen die Übersicht und der gespeicherte Mandant
  /// entstehen.
  final VorgangStartenDaten daten;

  /// Der verknüpfte Registereintrag — Vergleichsgrundlage der Übersicht bei
  /// einer Aktualisierung.
  final Mandant? gewaehlterMandant;

  /// Ob E-Mail und Kennzeichen formal in Ordnung sind; sonst bleibt der Knopf
  /// gesperrt, auch wenn es etwas zu speichern gäbe.
  final bool felderGueltig;

  /// Wie viele Vorgänge am verknüpften Registereintrag hängen — Zahl für die
  /// Warnung, wenn ein geänderter Name ihn umbenennt.
  final int vorgaengeAmMandanten;

  final void Function(MandantAenderungsart art, VorgangStartenDaten daten)
  onBestaetigt;

  const MandantSpeichernButton({
    super.key,
    required this.art,
    required this.daten,
    required this.gewaehlterMandant,
    required this.felderGueltig,
    required this.vorgaengeAmMandanten,
    required this.onBestaetigt,
  });

  /// Die Umbenennung, die ein Klick auslösen würde — null, solange der Name
  /// bleibt. Steht schon auf dem Knopf, nicht erst im Dialog: Wer „Mandanten
  /// umbenennen" liest, bevor er drückt, wird von der Rückfrage nicht
  /// überrascht.
  MandantUmbenennung? get _umbenennung => mandantUmbenennung(
    daten,
    gewaehlterMandant,
    vorgaengeAmMandanten: vorgaengeAmMandanten,
  );

  Future<void> _bestaetige(BuildContext context) async {
    final istNeu = art == MandantAenderungsart.neu;
    final zeilen = istNeu
        ? mandantNeuFelder(daten)
        : mandantDiff(daten, gewaehlterMandant!);
    final bestaetigt = await MandantUebersichtDialog.zeige(
      context,
      istNeu: istNeu,
      zeilen: zeilen,
      umbenennung: _umbenennung,
    );
    if (bestaetigt == true) onBestaetigt(art, daten);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VorgangStartenBloc, VorgangStartenState>(
      builder: (context, state) {
        final isLoading = state is VorgangStartenLoading;
        final offen = art != MandantAenderungsart.keine;
        final neu = art == MandantAenderungsart.neu;
        final aktiv = !isLoading && offen && felderGueltig;
        final benenntUm = _umbenennung != null;
        final icon = Icon(switch ((neu, benenntUm)) {
          (true, _) => Icons.person_add_alt_1_outlined,
          (false, true) => Icons.warning_amber_outlined,
          (false, false) => Icons.edit_note_outlined,
        });
        final beschriftung = Text(switch ((neu, benenntUm)) {
          (true, _) => 'Neuen Mandanten speichern',
          (false, true) => 'Mandanten umbenennen',
          (false, false) => 'Mandantendaten aktualisieren',
        });
        final gedrueckt = aktiv ? () => _bestaetige(context) : null;
        return Align(
          alignment: Alignment.centerRight,
          child: offen
              ? FilledButton.icon(
                  icon: icon,
                  label: beschriftung,
                  onPressed: gedrueckt,
                )
              : OutlinedButton.icon(
                  icon: icon,
                  label: beschriftung,
                  onPressed: gedrueckt,
                ),
        );
      },
    );
  }
}
