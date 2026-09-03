import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/seiten_app_bar.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_cubit.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_katalog_stand.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/services/register_filter.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_filter_leiste.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_leer_hinweis.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_spiegel_leiste.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_tabelle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Das Sachgebiete-Register (§6.2) im verbindlichen Spaltenschema —
/// laufende Nr. | Zeichen | Name ./. Gegner + Sachbestand | Rechtsgebiet.
///
/// Die Seite zeigt **alle** Vorgänge, nicht nur die abgeschlossenen; gefiltert
/// wird über die Leiste darüber. Der Knopf schreibt den Spiegel — die Word- und
/// PDF-Fassung im eingestellten Ablageordner. Liegt der im synchronisierten
/// Bereich, ist das Register damit unterwegs lesbar, ohne dass die App etwas
/// von der Cloud wissen muss.
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
  RegisterFilter _filter = RegisterFilter.alle;

  /// Ob gerade geschrieben wird. Bewusst hier und nicht im Cubit: Dessen
  /// Zustand ist das Ergebnis, und ein Cubit verwirft ein `emit` mit gleichem
  /// Wert — der Knopf bliebe also während des Laufs bedienbar, obwohl die
  /// PDF-Erzeugung Sekunden braucht.
  bool _schreibtGerade = false;

  /// Der [RegisterSpiegelCubit] ist als `factory` registriert — jeder Aufruf
  /// von `getIt` liefert eine **neue** Instanz, und niemand schließt sie.
  /// Deshalb hängt er am [BlocProvider] und nicht an einem Feld dieser Klasse:
  /// Der Provider schließt ihn beim Verlassen der Seite mit. Vorher blieb bei
  /// jedem Öffnen des Registers ein Cubit samt Stream offen zurück.
  ///
  /// Der [VorgangCubit] weiter unten hängt dagegen zu Recht direkt an `getIt` —
  /// er ist ein `lazySingleton` und gehört der App, nicht dieser Seite.
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RegisterSpiegelCubit>()..ladeStand(),
      child: Builder(builder: _geruest),
    );
  }

  /// Eigener Baumschritt unter dem Provider: Der [BuildContext] aus [build]
  /// steht noch darüber und fände den Cubit nicht.
  Widget _geruest(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: SeitenAppBar(
        titel: 'Sachgebiete-Register',
        icon: Icons.table_chart_outlined,
        untertitel: 'Alle Vorgänge im Registerschema der Kanzlei',
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
      body: BlocBuilder<VorgangCubit, List<Vorgang>>(
        bloc: getIt<VorgangCubit>(),
        builder: (context, vorgaenge) {
          if (vorgaenge.isEmpty) return const RegisterLeerHinweis();
          return _inhalt(theme, vorgaenge);
        },
      ),
    );
  }

  Future<void> _schreiben(BuildContext context) async {
    final spiegel = context.read<RegisterSpiegelCubit>();
    setState(() => _schreibtGerade = true);
    try {
      await spiegel.exportiere();
    } finally {
      if (mounted) setState(() => _schreibtGerade = false);
    }
  }

  Widget _inhalt(ThemeData theme, List<Vorgang> vorgaenge) {
    final zeilen = _filter.anwenden(vorgaenge);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          // Der Katalog (§7.1) speist die Rechtsgebiets-Auswahl; scheitert
          // sein Laden, filtert die Leiste sichtbar nur über den Bestand.
          child: BlocBuilder<SachgebietCubit, SachgebietKatalogStand>(
            bloc: getIt<SachgebietCubit>(),
            builder: (context, stand) => RegisterFilterLeiste(
              filter: _filter,
              alle: vorgaenge,
              onGeaendert: (filter) => setState(() => _filter = filter),
              katalog: switch (stand) {
                SachgebietKatalogGeladen(:final auswahl) => [
                  for (final sachgebiet in auswahl)
                    sachgebiet.rechtsgebietVorschlag,
                ],
                _ => const [],
              },
              katalogFehlt: stand is SachgebietKatalogFehler,
              onKatalogErneut: getIt<SachgebietCubit>().ladeErneut,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Text(
            _umfang(zeilen.length, vorgaenge.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: zeilen.isEmpty
                ? Text(
                    'Kein Vorgang passt zu dieser Auswahl.',
                    style: theme.textTheme.bodyMedium,
                  )
                : RegisterTabelle(zeilen: zeilen, mitStatus: true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: BlocBuilder<RegisterSpiegelCubit, RegisterSpiegelErgebnis>(
            builder: (context, stand) => RegisterSpiegelLeiste(stand: stand),
          ),
        ),
      ],
    );
  }

  String _umfang(int gezeigt, int gesamt) => gezeigt == gesamt
      ? '$gesamt Vorgänge. Neue Zeilen entstehen automatisch, sobald ein '
            'Vorgang abgeschlossen wird.'
      : '$gezeigt von $gesamt Vorgängen. Der Filter wirkt nur auf diese '
            'Ansicht — was in die Register-Datei kommt, steht in den '
            'Einstellungen.';
}
