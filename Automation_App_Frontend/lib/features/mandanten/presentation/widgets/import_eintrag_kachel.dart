import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/import_eintrag_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Eine Zeile der Importdatei, so wie der Dienst sie beurteilt hat — und der
/// Weg, sie vor dem Übernehmen richtigzustellen.
///
/// Die Hinweise stehen ausgeschrieben unter der Zeile und nicht hinter einem
/// Aufklapper: sie sind der Grund, warum diese Zeile überhaupt angesehen wird.
class ImportEintragKachel extends StatelessWidget {
  /// Das Urteil des Dienstes über diese Zeile.
  final ImportEintrag befund;

  /// Der Datensatz dahinter, der bearbeitet wird. Fehlt er, ist die Zeile nur
  /// zu lesen — dann stammt der Bericht nicht zur Datei daneben.
  final ImportMandantEintrag? datensatz;

  /// Falsch, solange eine Prüfung läuft oder schon übernommen wurde: eine
  /// Änderung träfe sonst einen Bericht, der gerade neu entsteht.
  final bool bearbeitbar;

  /// Diese Zeile nennt einen Ordner, den es im Stammordner nicht gibt — der
  /// Grund, warum die Übernahme gesperrt ist.
  final bool ordnerUnbekannt;

  /// Zu dieser Zeile steht ein ähnlicher Name im Register. Der Hinweis steht
  /// schon hier und nicht erst im Dialog, damit der Anwalt die Zeilen findet,
  /// ohne jede einzelne zu öffnen.
  final bool aehnlicherName;

  const ImportEintragKachel({
    super.key,
    required this.befund,
    required this.datensatz,
    this.bearbeitbar = false,
    this.ordnerUnbekannt = false,
    this.aehnlicherName = false,
  });

  bool get _aenderbar => bearbeitbar && datensatz != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;

    return ListTile(
      dense: true,
      onTap: _aenderbar ? () => _bearbeiten(context) : null,
      leading: Tooltip(
        message: befund.art.bezeichnung,
        child: Icon(_symbol, size: 20, color: _farbe(farben)),
      ),
      title: Text(
        befund.anzeigename.isEmpty
            ? 'Zeile ${befund.zeile + 1} ohne Namen'
            : befund.anzeigename,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_untertitel, style: theme.textTheme.bodySmall),
          for (final hinweis in befund.hinweise)
            Text(
              hinweis,
              style: theme.textTheme.bodySmall?.copyWith(color: farben.error),
            ),
          // Beides steht in der Unterzeile und nicht als Chip rechts: dort
          // stehen schon bis zu drei, und die Kachel bricht bei größerer
          // Schrift ohnehin knapp.
          if (ordnerUnbekannt)
            Text(
              'Nennt einen Ordner, den es im Stammordner nicht gibt.',
              style: theme.textTheme.bodySmall?.copyWith(color: farben.error),
            ),
          if (aehnlicherName)
            Text(
              'Ähnlicher Name im Register — beim Bearbeiten prüfen.',
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
            onPressed: _aenderbar ? () => _bearbeiten(context) : null,
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Zeile bearbeiten oder weglassen',
          ),
        ],
      ),
    );
  }

  Future<void> _bearbeiten(BuildContext context) async {
    // Der Dialog liegt auf einer eigenen Route und sieht den BlocProvider der
    // Seite nicht — deshalb wird der Cubit vorher gefasst und das Ergebnis
    // hier angewendet, statt im Dialog danach zu suchen. Aus demselben Grund
    // kommen Vorschläge und Ordnerbestand von hier: der Dialog holt sich
    // nichts selbst.
    final cubit = context.read<MandantenImportCubit>();
    final stand = cubit.state;
    final entscheidung = await showDialog<ImportEintragEntscheidung>(
      context: context,
      builder: (_) => ImportEintragDialog(
        befund: befund,
        datensatz: datensatz!,
        vorschlaege: stand.befund.aehnliche[befund.zeile] ?? const [],
        vorhandeneOrdner: stand.umfeld.ordnernamen,
      ),
    );
    if (entscheidung == null) return;

    final geaendert = entscheidung.geaendert;
    if (geaendert == null) {
      await cubit.eintragVerwerfen(befund.zeile);
    } else {
      await cubit.eintragErsetzen(befund.zeile, geaendert);
    }
  }

  String get _untertitel {
    final ordner = befund.aktenOrdnernamen;
    final teile = <String>[
      befund.art.bezeichnung,
      if (ordner.isEmpty) 'kein Ordner' else ordner.join(', '),
      if (befund.quelle.isNotEmpty) 'aus ${befund.quelle}',
    ];
    return teile.join(' · ');
  }

  IconData get _symbol => switch (befund.art) {
    ImportArt.neu => Icons.person_add_alt,
    ImportArt.ergaenzt => Icons.edit_note_outlined,
    ImportArt.unveraendert => Icons.remove_outlined,
    ImportArt.abgelehnt => Icons.report_gmailerrorred_outlined,
  };

  Color _farbe(ColorScheme farben) => switch (befund.art) {
    ImportArt.neu => farben.primary,
    ImportArt.ergaenzt => farben.tertiary,
    ImportArt.unveraendert => farben.outline,
    ImportArt.abgelehnt => farben.error,
  };
}
