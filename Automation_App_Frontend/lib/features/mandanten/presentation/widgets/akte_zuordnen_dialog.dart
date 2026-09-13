import 'package:automation_app/core/general_widgets/entity_search_bar.dart';
import 'package:automation_app/features/mandanten/domain/entities/akten_auswahl_eintrag.dart';
import 'package:automation_app/features/mandanten/domain/services/akten_auswahl.dart';
import 'package:automation_app/features/mandanten/presentation/widgets/akten_auswahl_kachel.dart';
import 'package:flutter/material.dart';

/// Das Gegenstück zum `ZuordnenDialog` (#132): Dort steht man beim Ordner und
/// sucht den Mandanten, hier steht man beim Mandanten und sucht den Ordner.
/// Liefert den gewählten Ordnernamen über `Navigator.pop`.
///
/// Gesucht wird über **alle** gescannten Ordner, nicht nur über den
/// Zuordnungsstapel: Beiseitegelegte und fremd zugeordnete stehen dort nicht,
/// und gerade die sucht, wer weiß, dass „dieser Ordner ihm gehört". Die
/// Ordner liegen seit dem Scan im Zustand der Übersicht vor — die Suche
/// filtert im Speicher und fragt keinen Dienst.
class AkteZuordnenDialog extends StatefulWidget {
  /// Wie der Mandant im Dialogkopf heißt.
  final String mandantName;

  /// Die geordnete Auswahl aus `MandantenOverviewLoaded.aktenAuswahlFuer`.
  final List<AktenAuswahlEintrag> eintraege;

  const AkteZuordnenDialog({
    super.key,
    required this.mandantName,
    required this.eintraege,
  });

  /// Höhe der Liste, höchstens. Vorgegeben statt `shrinkWrap`: Eine
  /// schrumpfende Liste muss ihre Gesamthöhe kennen und baut dafür jede Zeile
  /// — bei 4000 Ordnern der Dialog, der beim Öffnen hängt.
  static const double listenHoehe = 360;

  @override
  State<AkteZuordnenDialog> createState() => _AkteZuordnenDialogState();
}

class _AkteZuordnenDialogState extends State<AkteZuordnenDialog> {
  late List<AktenAuswahlEintrag> _treffer = widget.eintraege;
  String _suche = '';

  void _suchen(String suche) => setState(() {
    _suche = suche;
    _treffer = AktenAuswahl.filtere(widget.eintraege, suche);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vorschlaege = _treffer
        .where((e) => e.art == AktenAuswahlArt.namensvorschlag)
        .length;
    return AlertDialog(
      title: const Text('Akte zuordnen'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mandant: „${widget.mandantName}"'),
            const SizedBox(height: 12),
            EntitySearchBar(
              initialQuery: '',
              hintText: 'Ordner suchen …',
              onChanged: _suchen,
            ),
            const SizedBox(height: 8),
            Text(
              _zusammenfassung(vorschlaege),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            // Flexible: In einem niedrigen Fenster ist weniger Platz als
            // [listenHoehe], und die feste Höhe liefe unten aus dem Dialog.
            Flexible(
              child: SizedBox(
                height: AkteZuordnenDialog.listenHoehe,
                child: _treffer.isEmpty
                    ? Center(
                        child: Text(
                          _suche.trim().isEmpty
                              ? 'Im Stammordner liegt kein weiterer Ordner.'
                              : 'Kein Ordner passt zu „${_suche.trim()}".',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _treffer.length,
                        itemBuilder: (_, i) => AktenAuswahlKachel(
                          eintrag: _treffer[i],
                          onWaehlen: () => Navigator.pop(
                            context,
                            _treffer[i].akte.ordnername,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }

  String _zusammenfassung(int vorschlaege) {
    final ordner = '${_treffer.length} Ordner';
    if (vorschlaege == 0) return ordner;
    return '$ordner, davon $vorschlaege passend zum Namen — sie stehen oben';
  }
}
