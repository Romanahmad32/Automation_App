import 'package:flutter/material.dart';

/// Fragt nach einem Dateiwechsel, welche Felder mitgehen sollen, und liefert
/// die gewählten Namen — leer heißt: alles behalten (auch beim Wegtippen neben
/// den Dialog und bei leerer [felder]-Liste, dann steht gar kein Dialog auf).
///
/// Das Gegenstück zu `FeldAbgleich.verschwundeneFelder`: Der Dienst sammelt
/// die Kandidaten, dieser Dialog stellt sie zur Wahl, und gelöscht wird über
/// `VorlagenBearbeitung.felderEntfernen`.
Future<List<String>> zeigeAbgleichDialog(
  BuildContext context, {
  required String dateiname,
  required List<String> felder,
}) async {
  if (felder.isEmpty) return const [];
  final gewaehlt = await showDialog<List<String>>(
    context: context,
    builder: (_) => AbgleichDialog(dateiname: dateiname, felder: felder),
  );
  return gewaehlt ?? const [];
}

/// Der Dialog hinter [zeigeAbgleichDialog] — als eigenes Widget testbar.
///
/// Im Stil von `BestaetigungsDialog` (Symbol, Titel, Text, ablehnender
/// Textknopf links, destruktiver `FilledButton` rechts), aber nicht über ihn
/// gebaut: Der beantwortet Ja/Nein und sagt in seiner eigenen Beschreibung,
/// dass Dialoge mit Listen ein eigenes `AlertDialog` brauchen. Hier ist die
/// Antwort eine **Auswahl**, und die Häkchen tragen Zustand.
///
/// **Alles ist vorausgewählt.** Der übliche Fall ist die überarbeitete
/// Word-Datei, in der ein Platzhalter wirklich weggefallen ist; das Feld dazu
/// ist dann Altlast. Wer eine Zeile behalten will, nimmt ihr den Haken — und
/// wer gar nichts löschen will, drückt „Behalten". Nichts geht ungefragt weg.
class AbgleichDialog extends StatefulWidget {
  /// Die neu eingelesene Datei — mit Endung, wie sie im Explorer steht.
  final String dateiname;

  /// Die Feldnamen, deren Platzhalter nicht mehr vorkommt, in der Reihenfolge
  /// der Felder.
  final List<String> felder;

  const AbgleichDialog({
    super.key,
    required this.dateiname,
    required this.felder,
  });

  @override
  State<AbgleichDialog> createState() => _AbgleichDialogState();
}

class _AbgleichDialogState extends State<AbgleichDialog> {
  late final Set<String> _gewaehlt = {...widget.felder};

  /// Die gehakten Namen in der Reihenfolge der Felder — nicht in der des
  /// Anklickens: Die Liste geht als Löschauftrag zurück und soll lesbar
  /// bleiben, wenn sie in einer Meldung auftaucht.
  List<String> get _auswahl => [
    for (final feld in widget.felder)
      if (_gewaehlt.contains(feld)) feld,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final farben = theme.colorScheme;

    return AlertDialog(
      icon: Icon(Icons.playlist_remove, size: 40, color: farben.error),
      title: const Text('Datei neu eingelesen'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(
                'Diese Platzhalter kommen in ${widget.dateiname} nicht mehr '
                'vor. Welche Felder sollen entfernt werden?',
                style: theme.textTheme.bodyMedium,
              ),
              for (final feld in widget.felder)
                CheckboxListTile(
                  value: _gewaehlt.contains(feld),
                  onChanged: (an) => setState(
                    () => an ?? false
                        ? _gewaehlt.add(feld)
                        : _gewaehlt.remove(feld),
                  ),
                  title: Text(feld),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const <String>[]),
          child: const Text('Behalten'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: farben.error,
            foregroundColor: farben.onError,
          ),
          // Ohne Haken gibt es nichts zu entfernen; der Knopf täte dann
          // dasselbe wie „Behalten" und behauptete das Gegenteil.
          onPressed: _gewaehlt.isEmpty
              ? null
              : () => Navigator.of(context).pop(_auswahl),
          child: const Text('Ausgewählte entfernen'),
        ),
      ],
    );
  }
}
