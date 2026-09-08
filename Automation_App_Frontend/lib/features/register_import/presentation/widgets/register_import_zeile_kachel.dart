import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_zeile.dart';
import 'package:automation_app/features/register_import/domain/entities/register_zeilen_befund.dart';
import 'package:automation_app/features/register_import/presentation/blocs/register_import_cubit/register_import_cubit.dart';
import 'package:automation_app/features/register_import/presentation/widgets/register_import_zeile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eine Registerzeile, so wie der Dienst sie beurteilt hat — und der Weg, sie
/// vor dem Übernehmen richtigzustellen.
///
/// Die Spalten sind die des Word-Registers: Nummer, Zeichen, Sache. Daneben
/// steht, was die Datei nicht sagen kann: wie sicher sich der Erzeuger war und
/// was der Dienst gefunden hat. Die Befunde stehen ausgeschrieben unter der
/// Zeile und nicht hinter einem Aufklapper — sie sind der Grund, warum diese
/// Zeile überhaupt angesehen wird.
class RegisterImportZeileKachel extends StatelessWidget {
  /// Das Urteil des Dienstes über diese Zeile.
  final RegisterZeilenBefund befund;

  /// Der Datensatz dahinter, der bearbeitet wird. Fehlt er, ist die Zeile nur
  /// zu lesen — dann gehört der Bericht nicht zur Datei daneben.
  final RegisterImportZeile? datensatz;

  /// Falsch, solange eine Prüfung läuft oder der Jahrgang schon geschrieben
  /// wurde: eine Änderung träfe sonst einen Bericht, der gerade neu entsteht.
  final bool bearbeitbar;

  const RegisterImportZeileKachel({
    super.key,
    required this.befund,
    required this.datensatz,
    this.bearbeitbar = false,
  });

  bool get _aenderbar => bearbeitbar && datensatz != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;

    return ListTile(
      dense: true,
      onTap: _aenderbar ? () => bearbeiten(context) : null,
      leading: SizedBox(
        width: 44,
        child: Text(
          '${befund.laufendeNummer}',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: befund.zuPruefen ? farben.onSurface : farben.outline,
          ),
        ),
      ),
      title: Text(
        befund.anzeigetext.isEmpty
            ? 'Zeile ${befund.zeile} ohne Parteien'
            : befund.anzeigetext,
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_untertitel, style: theme.textTheme.bodySmall),
          for (final meldung in befund.befunde)
            Text(
              meldung,
              style: theme.textTheme.bodySmall?.copyWith(color: farben.error),
            ),
          for (final hinweis in befund.hinweise)
            Text(
              hinweis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: farben.tertiary,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (datensatz?.bearbeitet ?? false)
            Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('bearbeitet'),
              labelStyle: theme.textTheme.labelSmall,
            ),
          if (befund.sicherheit != ImportSicherheit.hoch)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(befund.sicherheit.bezeichnung),
              labelStyle: theme.textTheme.labelSmall,
            ),
          IconButton(
            onPressed: _aenderbar ? () => bearbeiten(context) : null,
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Zeile bearbeiten oder weglassen',
          ),
        ],
      ),
    );
  }

  /// Öffnet den Bearbeitungsdialog und wendet die Entscheidung an.
  ///
  /// Der Dialog liegt auf einer eigenen Route und sieht den BlocProvider der
  /// Seite nicht — deshalb wird der Cubit vorher gefasst und das Ergebnis hier
  /// angewendet, statt im Dialog danach zu suchen.
  Future<void> bearbeiten(BuildContext context) async {
    final cubit = context.read<RegisterImportCubit>();
    final entscheidung = await showDialog<RegisterZeileEntscheidung>(
      context: context,
      builder: (_) =>
          RegisterImportZeileDialog(befund: befund, datensatz: datensatz!),
    );
    if (entscheidung == null) return;

    final geaendert = entscheidung.geaendert;
    if (geaendert == null) {
      await cubit.zeileVerwerfen(befund.jahrgang, befund.zeile);
    } else {
      await cubit.zeileErsetzen(befund.jahrgang, befund.zeile, geaendert);
    }
  }

  /// Zeichen und Rechtsgebiet — die beiden Spalten, an denen der Anwalt die
  /// Zeile im Word-Register wiederfindet.
  String get _untertitel {
    final teile = <String>[
      if (befund.aktenzeichen.isNotEmpty) befund.aktenzeichen,
      if (befund.rechtsgebiet.isNotEmpty) befund.rechtsgebiet,
      if (befund.art == ImportArt.unveraendert) 'steht schon im Register',
      if (befund.art == ImportArt.abgelehnt) 'wird nicht übernommen',
    ];
    return teile.join(' · ');
  }
}
