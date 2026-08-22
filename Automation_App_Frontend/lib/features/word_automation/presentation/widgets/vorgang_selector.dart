import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_navigation_signal.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Auswahl des Vorgangs, aus dem das Schreiben erstellt wird (Phase 4). Liest
/// die persistierten Vorgänge aus dem app-weiten [VorgangCubit] und liefert sie
/// als Quelle für die Vorbelegung. Beim ersten Anzeigen wird — sofern der
/// Anwender noch nichts gewählt hat — der zuletzt beantwortete Vorgang
/// vorausgewählt (typischer Weg: Antwort übernommen → Tab Word). Über
/// „(kein Vorgang)" lässt sich die Auswahl wieder aufheben.
class VorgangSelector extends StatefulWidget {
  const VorgangSelector({super.key});

  @override
  State<VorgangSelector> createState() => _VorgangSelectorState();
}

class _VorgangSelectorState extends State<VorgangSelector> {
  bool _autoSelectVersucht = false;

  final VorgangNavigationSignal _navSignal = getIt<VorgangNavigationSignal>();

  @override
  void initState() {
    super.initState();
    // Gezielte Vorauswahl beim Wechsel aus „Vorgang starten" → Word. Greift auch,
    // wenn der Tab bereits gebaut ist (AutoTabsRouter hält ihn am Leben).
    _navSignal.pendingReferenz.addListener(_onNavSignal);
    _onNavSignal();
  }

  @override
  void dispose() {
    _navSignal.pendingReferenz.removeListener(_onNavSignal);
    super.dispose();
  }

  void _onNavSignal() {
    final referenz = _navSignal.pendingReferenz.value;
    if (referenz == null) return;
    final vorgaenge = getIt<VorgangCubit>().state;
    for (final vorgang in vorgaenge) {
      if (Vorgang.gleicheReferenz(vorgang.referenz, referenz)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<WizardCubit>().selectVorgang(vorgang);
        });
        break;
      }
    }
    _navSignal.loesche();
  }

  /// Vorauswahl-Vorschlag: der zuletzt aktualisierte Vorgang mit Antwort
  /// (uebernehmeAntwort hängt ihn ans Listenende), sonst der zuletzt angelegte.
  Vorgang? _vorschlag(List<Vorgang> vorgaenge) {
    if (vorgaenge.isEmpty) return null;
    for (final vorgang in vorgaenge.reversed) {
      if (vorgang.antwort != null) return vorgang;
    }
    return vorgaenge.last;
  }

  String _label(Vorgang vorgang) {
    final teile = <String>[
      vorgang.referenz,
      if ((vorgang.mandantName ?? '').trim().isNotEmpty) vorgang.mandantName!,
    ];
    return '${teile.join(' · ')}  (${vorgang.status.displayName})';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VorgangCubit, List<Vorgang>>(
      bloc: getIt<VorgangCubit>(),
      builder: (context, vorgaenge) {
        final selected = context.select<WizardCubit, Vorgang?>(
          (cubit) => cubit.state.selectedVorgang,
        );

        // Einmalige Vorauswahl, sobald Vorgänge vorliegen und der Anwender noch
        // nichts gewählt hat. Nach dem Frame, um setState/emit im Build zu
        // vermeiden.
        if (!_autoSelectVersucht && selected == null && vorgaenge.isNotEmpty) {
          _autoSelectVersucht = true;
          final vorschlag = _vorschlag(vorgaenge);
          if (vorschlag != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.read<WizardCubit>().selectVorgang(vorschlag);
            });
          }
        }

        if (vorgaenge.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.folder_off_outlined),
              title: Text('Kein Vorgang vorhanden'),
              subtitle: Text(
                'Starten Sie eine Zentralruf-Anfrage oder übernehmen Sie eine '
                'Antwort, um Felder automatisch vorzubelegen.',
              ),
            ),
          );
        }

        // Der ausgewählte Vorgang kann inzwischen (z. B. neuer Status) ersetzt
        // worden sein; Auswahl über die stabile Referenz abgleichen.
        final selektierteReferenz = selected == null
            ? null
            : (vorgaenge.any(
                    (v) =>
                        Vorgang.gleicheReferenz(v.referenz, selected.referenz),
                  )
                  ? Vorgang.normalizeReferenz(selected.referenz)
                  : null);

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SearchableDropdown<String?>(
              value: selektierteReferenz,
              labelText: 'Vorgang',
              hintText: 'Vorgang suchen oder auswählen',
              helperText: 'Liefert Mandant, Antwort und Rechtsgebiet.',
              helperMaxLines: 2,
              border: InputBorder.none,
              entries: [
                const SearchableDropdownEntry<String?>(
                  value: null,
                  label: '(kein Vorgang)',
                ),
                for (final vorgang in vorgaenge)
                  SearchableDropdownEntry<String?>(
                    value: Vorgang.normalizeReferenz(vorgang.referenz),
                    label: _label(vorgang),
                  ),
              ],
              onChanged: (referenz) {
                final cubit = context.read<WizardCubit>();
                if (referenz == null) {
                  cubit.selectVorgang(null);
                  return;
                }
                for (final vorgang in vorgaenge) {
                  if (Vorgang.normalizeReferenz(vorgang.referenz) == referenz) {
                    cubit.selectVorgang(vorgang);
                    return;
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }
}
