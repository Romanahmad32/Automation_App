import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/core/router/app_router.gr.dart';
import 'package:automation_app/core/router/app_tab_index.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_cubit.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_katalog_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_meldung.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_state.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_hervorhebung_signal.dart';
import 'package:automation_app/features/vorgaenge/presentation/views/register_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Das Sachgebiete-Register (§6.2) im verbindlichen Spaltenschema —
/// Lfd. Nr. | Zeichen | Sache · Sachbestand | Rechtsgebiet | Status.
///
/// Die Zeilen kommen seit Issue #109 **fertig gebaut aus dem Backend** und
/// führen laufende Vorgänge und die übernommene Registerhistorie der Kanzlei in
/// einer Folge. Vorher leitete diese Seite ihre Zellen selbst aus den
/// Vorgängen ab, während die Word-/PDF-Datei dieselbe Rechnung im Dienst noch
/// einmal machte — zwei Quellen, deren Auseinanderlaufen niemandem auffiel.
///
/// Der Knopf oben schreibt den Spiegel — die Word- und PDF-Fassung im
/// eingestellten Ablageordner. Liegt der im synchronisierten Bereich, ist das
/// Register damit unterwegs lesbar, ohne dass die App etwas von der Cloud
/// wissen muss.
///
/// Wichtig für das Verständnis der Seite: Der Filter hier wirkt **nur auf den
/// Bildschirm**. Was in die Datei kommt, steht in den Einstellungen — sonst
/// hinge der Inhalt einer Datei, die andere lesen, davon ab, was zuletzt am
/// Bildschirm eingestellt war.
@RoutePage()
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  /// Ob gerade geschrieben wird. Bewusst hier und nicht im Cubit: Dessen
  /// Zustand ist das Ergebnis, und ein Cubit verwirft ein `emit` mit gleichem
  /// Wert — der Knopf bliebe also während des Laufs bedienbar, obwohl die
  /// PDF-Erzeugung Sekunden braucht.
  bool _schreibtGerade = false;

  /// Beide Cubits sind als `factory` registriert — jeder Aufruf von `getIt`
  /// liefert eine **neue** Instanz, und niemand schließt sie. Deshalb hängen
  /// sie am [BlocProvider] und nicht an Feldern dieser Klasse: Der Provider
  /// schließt sie beim Verlassen der Seite mit.
  ///
  /// Der [VorgangCubit] weiter unten hängt dagegen zu Recht direkt an `getIt` —
  /// er ist ein `lazySingleton` und gehört der App, nicht dieser Seite.
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<RegisterCubit>()..lade()),
        BlocProvider(create: (_) => getIt<RegisterSpiegelCubit>()..ladeStand()),
      ],
      child: Builder(builder: _geruest),
    );
  }

  /// Eigener Baumschritt unter den Providern: Der [BuildContext] aus [build]
  /// steht noch darüber und fände die Cubits nicht.
  Widget _geruest(BuildContext context) {
    return Scaffold(
      appBar: SeitenAppBar(
        titel: 'Sachgebiete-Register',
        icon: Icons.table_chart_outlined,
        untertitel: 'Alle Vorgänge und die übernommene Historie',
        aktionen: [
          Tooltip(
            message:
                'Schreibt das Register als Word- und PDF-Datei in den '
                'eingestellten Ablageordner. Nach jedem Abschluss geschieht '
                'das automatisch.',
            child: OutlinedButton.icon(
              onPressed: _schreibtGerade ? null : () => _schreiben(context),
              icon: _schreibtGerade
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_outlined),
              label: const Text('Register jetzt schreiben'),
            ),
          ),
        ],
      ),
      body: BlocBuilder<RegisterCubit, RegisterState>(
        builder: (context, state) => _mitUmfeld(context, state),
      ),
    );
  }

  /// Was die Ansicht außer ihrem eigenen Zustand noch braucht: den
  /// Sachgebietskatalog (§7.1) für die Rechtsgebiets-Auswahl und den
  /// Vorgangsbestand für die Statusspalte. Beides kommt aus `getIt` und bleibt
  /// deshalb hier, damit [RegisterView] ohne DI prüfbar ist.
  Widget _mitUmfeld(BuildContext context, RegisterState state) {
    return BlocBuilder<SachgebietCubit, SachgebietKatalogStand>(
      bloc: getIt<SachgebietCubit>(),
      builder: (context, katalogStand) =>
          BlocBuilder<VorgangCubit, List<Vorgang>>(
            bloc: getIt<VorgangCubit>(),
            builder: (context, vorgaenge) => RegisterView(
              state: state,
              katalog: switch (katalogStand) {
                SachgebietKatalogGeladen(:final auswahl) => [
                  for (final sachgebiet in auswahl)
                    sachgebiet.rechtsgebietVorschlag,
                ],
                _ => const [],
              },
              katalogFehlt: katalogStand is SachgebietKatalogFehler,
              onKatalogErneut: getIt<SachgebietCubit>().ladeErneut,
              statusJeReferenz: {
                for (final vorgang in vorgaenge)
                  vorgang.referenz: vorgang.status,
              },
              onDateiEinlesen: () => _importOeffnen(context, state),
              onVorgangOeffnen: (zeile) => _vorgangOeffnen(context, zeile),
            ),
          ),
    );
  }

  /// Schreibt den Spiegel und sagt danach, was daraus geworden ist — als
  /// flüchtige Meldung oben rechts, wie überall in der App.
  ///
  /// Vorher stand das Ergebnis nur in der Leiste am **Fuß** der Seite: Wer
  /// oben auf den Knopf gedrückt hatte, blieb ohne Antwort, und ein Fehlschlag
  /// blieb unter tausenden Zeilen liegen. Der Griff auf [Rueckmeldung] wird vor
  /// dem `await` gefasst — danach ist der Kontext womöglich fort.
  Future<void> _schreiben(BuildContext context) async {
    final spiegel = context.read<RegisterSpiegelCubit>();
    final rueckmeldung = Rueckmeldung.von(context);
    setState(() => _schreibtGerade = true);
    try {
      await spiegel.exportiere();
    } finally {
      if (mounted) setState(() => _schreibtGerade = false);
    }
    RegisterSpiegelMeldung.zu(spiegel.state).zeige(rueckmeldung);
  }

  /// Der Sprung vom Register in die Vorgangsverwaltung (Tab 7).
  ///
  /// Das Register ist ein Verzeichnis: Man findet dort eine Sache wieder und
  /// will dann an sie heran. Gearbeitet wird aber nicht hier — Bearbeiten und
  /// Löschen liegen in der Verwaltung, und zwei Pflegeorte für denselben
  /// Vorgang wären einer zu viel. Das Signal sorgt dafür, dass die Liste dort
  /// zur Zeile scrollt und sie hervorhebt, statt den Anwalt unter Hunderten
  /// selbst suchen zu lassen.
  void _vorgangOeffnen(BuildContext context, RegisterZeile zeile) {
    final referenz = zeile.vorgangReferenz;
    if (referenz == null) return;
    getIt<VorgangHervorhebungSignal>().setze(referenz);
    AutoTabsRouter.of(context).setActiveIndex(AppTabIndex.vorgaenge);
  }

  /// „Datei einlesen…" führt auf die Import-Seite: Die Anleitung für den
  /// Erzeuger der Datei steht dort neben dem Einlesen, und ein eigener Dialog
  /// oder ein zweiter Knopf hier wäre eine weitere Stelle, an der sie veraltet.
  ///
  /// Der Vorschlag ist der kleinste fehlende Jahrgang, sonst das Vorjahr — die
  /// Import-Seite trägt ihn in die Anleitung ein.
  Future<void> _importOeffnen(BuildContext context, RegisterState state) async {
    final cubit = context.read<RegisterCubit>();
    await context.router.push(
      RegisterImportRoute(vorgeschlagenerJahrgang: state.stand.vorschlag()),
    );
    // Nach der Rückkehr steht der Bestand anders da, wenn übernommen wurde.
    await cubit.lade();
  }
}
