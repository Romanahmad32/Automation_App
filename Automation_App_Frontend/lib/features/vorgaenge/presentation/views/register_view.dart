import 'package:automation_app/core/general_widgets/bestaetigungs_dialog.dart';
import 'package:automation_app/core/general_widgets/fehler_hinweis.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_spiegel_ergebnis.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_zeile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_state.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/historie_stand_karte.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/historie_zeile_dialog.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_filter_leiste.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_leer_hinweis.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_spiegel_leiste.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/register_tabelle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Inhalt der Registerseite (§6.2): Stand der übernommenen Historie,
/// Filterleiste, Tabelle, Spiegelleiste.
///
/// Eigenes Widget neben `RegisterPage`, damit die Seite nur noch verdrahtet
/// (Provider, Kopfzeile, Export-Knopf) und dieser Teil ohne `getIt` prüfbar
/// bleibt — alles, was aus der DI kommt, wird hereingereicht.
class RegisterView extends StatelessWidget {
  final RegisterState state;

  /// Die Rechtsgebiete des Sachgebietskatalogs (§7.1); leer, solange er lädt
  /// oder nicht erreichbar ist.
  final List<String> katalog;
  final bool katalogFehlt;
  final VoidCallback? onKatalogErneut;

  /// Der Lebenszyklus-Status je Vorgangsreferenz — die Registerzeile trägt ihn
  /// nicht, sie weiß nur, ob sie abgeschlossen ist.
  final Map<String, VorgangStatus> statusJeReferenz;

  /// Öffnet die Import-Seite; „Anleitung" führt auf dieselbe Seite.
  final VoidCallback? onDateiEinlesen;
  final VoidCallback? onAnleitung;

  const RegisterView({
    super.key,
    required this.state,
    this.katalog = const [],
    this.katalogFehlt = false,
    this.onKatalogErneut,
    this.statusJeReferenz = const {},
    this.onDateiEinlesen,
    this.onAnleitung,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sichtbar = state.sichtbar;
    final cubit = context.read<RegisterCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: HistorieStandKarte(
            stand: state.stand,
            onDateiEinlesen: onDateiEinlesen,
            onAnleitung: onAnleitung,
            gewaehlterJahrgang: state.filter.jahr,
            onJahrgang: (jahrgang) =>
                cubit.filtern(state.filter.mit(jahr: '$jahrgang')),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: RegisterFilterLeiste(
            filter: state.filter,
            alle: state.zeilen,
            onGeaendert: cubit.filtern,
            katalog: katalog,
            katalogFehlt: katalogFehlt,
            onKatalogErneut: onKatalogErneut,
          ),
        ),
        if (state.fehler != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: FehlerHinweis(nachricht: state.fehler!),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Text(
            _umfang(sichtbar.length, state.zeilen.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: _tabelle(context, theme, sichtbar),
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

  Widget _tabelle(
    BuildContext context,
    ThemeData theme,
    List<RegisterZeile> sichtbar,
  ) {
    if (state.zeilen.isEmpty) {
      return state.laedt
          ? const Center(child: CircularProgressIndicator())
          : const RegisterLeerHinweis();
    }
    if (sichtbar.isEmpty) {
      return Text(
        'Keine Zeile passt zu dieser Auswahl.',
        style: theme.textTheme.bodyMedium,
      );
    }
    return RegisterTabelle(
      zeilen: sichtbar,
      mitStatus: true,
      mitJahreszeilen: true,
      statusJeReferenz: statusJeReferenz,
      onHistorieZeile: (zeile) => _zeileBearbeiten(context, zeile),
    );
  }

  String _umfang(int gezeigt, int gesamt) => gezeigt == gesamt
      ? '$gesamt Zeilen. Neue entstehen automatisch, sobald ein Vorgang '
            'abgeschlossen wird — ältere kommen über „Datei einlesen…" dazu.'
      : '$gezeigt von $gesamt Zeilen. Der Filter wirkt nur auf diese Ansicht — '
            'was in die Register-Datei kommt, steht in den Einstellungen.';

  /// Berichtigt eine historische Zeile: Rohstand holen, Dialog, Rückfrage,
  /// schreiben.
  ///
  /// Der Rohstand kommt erst hier über die Leitung (`GET
  /// /api/RegisterHistorie/{id}`): Die Tabelle trägt die Anzeigeform, der
  /// Dialog braucht die Einzelfelder, und für tausende Zeilen wäre das Ballast
  /// für den einen Klick, der sie braucht.
  ///
  /// Die Rückfrage steht **nach** dem Dialog und nicht davor: Vorher wüsste der
  /// Anwalt noch nicht, was er bestätigt. Und sie steht überhaupt, weil hier
  /// der Bestand der Kanzlei geändert wird — nicht eine Ansicht.
  Future<void> _zeileBearbeiten(
    BuildContext context,
    RegisterZeile zeile,
  ) async {
    final id = zeile.historieId;
    if (id == null) return;
    final cubit = context.read<RegisterCubit>();
    final rueckmeldung = Rueckmeldung.von(context);

    final roh = await cubit.ladeHistorieZeile(id);
    if (roh == null) {
      rueckmeldung.fehler(
        'Der Registereintrag ${zeile.zeichen} konnte nicht geladen werden.',
      );
      return;
    }
    if (!context.mounted) return;

    final entscheidung = await showDialog<HistorieZeileEntscheidung>(
      context: context,
      builder: (_) => HistorieZeileDialog(zeile: roh, zeichen: zeile.zeichen),
    );
    if (entscheidung == null || !context.mounted) return;

    final zugestimmt = await bestaetigen(
      context,
      titel: 'Registereintrag ändern?',
      text:
          'Die Zeile ${zeile.zeichen} wird im Register geändert. Der '
          'Freitext aus dem Registerbuch bleibt als Beleg erhalten, die '
          'Befunde werden neu gerechnet.',
      bestaetigung: 'Ändern',
      icon: Icons.edit_outlined,
    );
    if (!zugestimmt) return;

    final erfolg = await cubit.aendereHistorie(id, entscheidung.aenderung);
    if (erfolg) {
      rueckmeldung.erfolg('Registereintrag ${zeile.zeichen} geändert.');
    } else {
      rueckmeldung.fehler(
        'Der Registereintrag ${zeile.zeichen} konnte nicht geändert werden.',
      );
    }
  }
}
