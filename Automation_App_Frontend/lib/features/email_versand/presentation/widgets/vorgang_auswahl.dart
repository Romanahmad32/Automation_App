import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Wahl des Vorgangs im Versanddialog (§4.7) — das erste Feld, weil alles
/// Weitere daraus vorbelegt wird: Empfänger, Betreff, Anrede und die
/// Platzhalter der Vorlage.
///
/// **Der Grund, warum es hier steht und nicht nur an den aufrufenden Stellen:**
/// Aus dem Postfach geht der Dialog auch dann auf, wenn sich die Antwort keinem
/// Vorgang zuordnen liess (§4.3) — dann stand dort ein leeres Anschreiben, und
/// „Keine Vorlage (Vorbelegung aus dem Vorgang)" versprach eine Vorbelegung,
/// die es nicht gab. Mit diesem Schalter ist der Vorgang nachzutragen, ohne den
/// Entwurf zu schliessen und neu zu öffnen.
///
/// Der Bestand kommt aus dem `VorgangCubit` — demselben, aus dem die
/// Registeransicht liest; ein eigener Abruf daneben liefe auseinander.
class VorgangAuswahl extends StatelessWidget {
  const VorgangAuswahl({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: getIt<VorgangCubit>(),
      child: const VorgangAuswahlFeld(),
    );
  }
}

/// Das Auswahlfeld selbst, unter dem bereitgestellten [VorgangCubit].
class VorgangAuswahlFeld extends StatelessWidget {
  const VorgangAuswahlFeld({super.key});

  /// Wie ein Vorgang in der Liste steht: das **Zeichen** zuerst, denn danach
  /// sucht der Anwalt — es steht auf dem Schriftsatz. Der Mandantenname
  /// dahinter bestätigt den Treffer.
  ///
  /// Angezeigt wird das Zeichen (`216/26 C03`), nicht die volle Referenz
  /// (§4.2, nachgezogen am 03.09.2026): Das Kennzeichen darin ist ein
  /// Ordnungsmerkmal der Ablage und in einer Auswahlliste nur Länge. Der
  /// **Wert** des Eintrags bleibt die volle Referenz — er muss den Vorgang
  /// eindeutig treffen, und zwei Vorgänge desselben Mandanten teilen sich ein
  /// Zeichen nicht, aber ein gekürztes Zeichen wäre der falsche Schlüssel.
  static String beschriftungFuer(Vorgang vorgang) {
    final name = (vorgang.mandantName ?? '').trim();
    final gegner = (vorgang.gegner ?? '').trim();
    final zusatz = [
      if (name.isNotEmpty) name,
      if (gegner.isNotEmpty) './. $gegner',
    ].join(' ');
    return zusatz.isEmpty ? vorgang.zeichen : '${vorgang.zeichen} · $zusatz';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VorgangCubit, List<Vorgang>>(
      builder: (context, bestand) {
        return BlocBuilder<EmailEntwurfCubit, EmailEntwurfState>(
          buildWhen: (vorher, jetzt) =>
              vorher.vorgang != jetzt.vorgang ||
              vorher.beschaeftigt != jetzt.beschaeftigt,
          builder: (context, entwurf) {
            final gewaehlt = entwurf.vorgang;

            // Der gewählte Vorgang muss in der Liste stehen, sonst zeigt das
            // Feld nichts an: Der Bestand kann noch laden, und aus dem
            // Word-Assistenten kommt der Vorgang mitgegeben.
            final eintraege = <SearchableDropdownEntry<String>>[
              const SearchableDropdownEntry(
                value: '',
                label: 'Kein Vorgang (leeres Anschreiben)',
              ),
              for (final vorgang in _bestandMit(bestand, gewaehlt))
                SearchableDropdownEntry(
                  value: vorgang.referenz,
                  label: beschriftungFuer(vorgang),
                ),
            ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              // `SearchableDropdown` kennt kein `enabled`; abgeblendet und
              // taub ist ehrlicher als ein Feld, das sich aufziehen lässt und
              // die Wahl dann verschluckt.
              child: Opacity(
                opacity: entwurf.beschaeftigt ? 0.5 : 1,
                child: IgnorePointer(
                  ignoring: entwurf.beschaeftigt,
                  child: SearchableDropdown<String>(
                    // Über die Referenz statt über den Vorgang selbst: Sie ist
                    // der fachliche Schlüssel, und ein nebenher
                    // aktualisierter Registereintrag wäre als Objekt nicht
                    // mehr derselbe Wert.
                    value: gewaehlt?.referenz ?? '',
                    entries: eintraege,
                    labelText: 'Vorgang',
                    hintText: 'Referenz oder Mandant suchen',
                    helperText:
                        'Belegt Empfänger, Betreff und die Platzhalter der '
                        'Vorlage vor. Danach ist alles änderbar.',
                    helperMaxLines: 2,
                    leadingIcon: const Icon(Icons.folder_outlined),
                    onChanged: (referenz) =>
                        context.read<EmailEntwurfCubit>().waehleVorgang(
                          _zuReferenz(_bestandMit(bestand, gewaehlt), referenz),
                        ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Der Bestand samt dem gewählten Vorgang, auch wenn der noch nicht in der
  /// Liste steht.
  static List<Vorgang> _bestandMit(List<Vorgang> bestand, Vorgang? gewaehlt) {
    if (gewaehlt == null) return bestand;
    if (bestand.any((eintrag) => eintrag.referenz == gewaehlt.referenz)) {
      return bestand;
    }
    return [gewaehlt, ...bestand];
  }

  static Vorgang? _zuReferenz(List<Vorgang> bestand, String? referenz) {
    if (referenz == null || referenz.isEmpty) return null;
    return bestand.where((vorgang) => vorgang.referenz == referenz).firstOrNull;
  }
}
