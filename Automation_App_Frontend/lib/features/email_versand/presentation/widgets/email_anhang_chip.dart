import 'package:automation_app/features/email_versand/presentation/utils/anhang_darstellung.dart';
import 'package:automation_app/features/email_versand/presentation/utils/anhang_oeffner.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/anhang_umbenennen_dialog.dart';
import 'package:flutter/material.dart';

/// Ein angehängtes Dokument im Versanddialog (§4.7): Klick auf den Namen öffnet
/// es, das Stiftsymbol benennt es um, das Kreuz entfernt es.
///
/// Das Öffnen ist der Grund für dieses Widget. Vor dem Absenden gibt es genau
/// eine Frage, die sich aus dem Dateinamen nicht beantworten lässt — hängt da
/// wirklich das richtige Schreiben dran? — und sie zu beantworten darf nicht
/// heißen, den Dialog zu verlassen.
class EmailAnhangChip extends StatefulWidget {
  /// Breitengrenze für den Namen. Der Chip steht in einem `Wrap` und hat
  /// deshalb keine Breite, gegen die er umbrechen könnte — ein im
  /// Umbenennen-Dialog vergebener langer Name schöbe sonst Stift und Kreuz aus
  /// dem Dialog hinaus. Gekürzt bleibt der volle Name im Tooltip lesbar.
  static const double maxNameBreite = 260;

  final String pfad;

  /// Der Name, unter dem der Anhang hinausgeht — nicht zwingend der auf Platte.
  final String name;

  final ValueChanged<String> onUmbenennen;
  final VoidCallback onEntfernen;
  final bool aktiv;

  const EmailAnhangChip({
    super.key,
    required this.pfad,
    required this.name,
    required this.onUmbenennen,
    required this.onEntfernen,
    this.aktiv = true,
  });

  @override
  State<EmailAnhangChip> createState() => _EmailAnhangChipState();
}

class _EmailAnhangChipState extends State<EmailAnhangChip> {
  /// Einmal gelesen statt bei jedem Neubau: Das Formular baut bei jedem
  /// Tastendruck neu, und ein `lengthSync` je Anhang und Anschlag wäre
  /// Plattenzugriff im Takt der Tastatur.
  String _groesse = '';

  @override
  void initState() {
    super.initState();
    _groesse = AnhangDarstellung.groesse(widget.pfad);
  }

  @override
  void didUpdateWidget(EmailAnhangChip alt) {
    super.didUpdateWidget(alt);
    if (alt.pfad != widget.pfad) {
      _groesse = AnhangDarstellung.groesse(widget.pfad);
    }
  }

  Future<void> _oeffnen(BuildContext context) async {
    final melder = ScaffoldMessenger.of(context);
    if (await AnhangOeffner.oeffne(widget.pfad)) return;

    melder.showSnackBar(
      SnackBar(
        content: Text(
          '„${widget.name}" lässt sich nicht öffnen — liegt die Datei noch dort?',
        ),
        action: SnackBarAction(
          label: 'Im Ordner zeigen',
          onPressed: () => AnhangOeffner.zeigeImOrdner(widget.pfad),
        ),
      ),
    );
  }

  Future<void> _umbenennen(BuildContext context) async {
    final neu = await AnhangUmbenennenDialog.zeigen(context, widget.name);
    if (neu != null) widget.onUmbenennen(neu);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aufPlatte = AnhangDarstellung.name(widget.pfad);
    final umbenannt = widget.name != aufPlatte;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: umbenannt
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              )
            : null,
      ),
      padding: const EdgeInsets.only(left: 10, right: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            umbenannt ? Icons.drive_file_rename_outline : Icons.attach_file,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          // Der volle Pfad gehört in den Tooltip, nicht in die Zeile: Mit Pfad
          // erkennt niemand mehr, welches Dokument das ist.
          Tooltip(
            message: [
              widget.pfad,
              if (umbenannt) 'geht hinaus als: ${widget.name}',
              if (_groesse.isNotEmpty) _groesse,
              'Klick öffnet die Datei',
            ].join('\n'),
            child: InkWell(
              onTap: () => _oeffnen(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: EmailAnhangChip.maxNameBreite,
                  ),
                  child: Text(
                    widget.name,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Für die Mail umbenennen',
            visualDensity: VisualDensity.compact,
            onPressed: widget.aktiv ? () => _umbenennen(context) : null,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            tooltip: 'Anhang entfernen',
            visualDensity: VisualDensity.compact,
            onPressed: widget.aktiv ? widget.onEntfernen : null,
          ),
        ],
      ),
    );
  }
}
