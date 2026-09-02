import 'package:automation_app/features/form_template_setup/domain/services/platzhalter_zuordnung.dart';
import 'package:flutter/material.dart';

/// Was im [ZuordnungsDialog] gewählt wurde.
sealed class ZuordnungsWahl {
  const ZuordnungsWahl();
}

/// „Neues Feld anlegen" — der Weg, den ein Klick auf den Chip früher ohne
/// Rückfrage ging.
final class NeuesFeldAnlegen extends ZuordnungsWahl {
  const NeuesFeldAnlegen();
}

/// „Diesen Namen nehmen": Das Gegenstück wird umbenannt, statt ein zweites
/// anzulegen.
final class NamenUebernehmen extends ZuordnungsWahl {
  final String name;

  const NamenUebernehmen(this.name);
}

/// Bringt einen Namen ohne Gegenstück mit der anderen Seite zusammen (#36).
///
/// Beide Richtungen enden hier: der **Platzhalter ohne Feld** (Klick auf einen
/// offenen Chip) und das **Feld ohne Platzhalter** (Klick auf sein
/// Kennzeichen). Oben stehen die Vorschläge von [PlatzhalterZuordnung],
/// darunter aufklappbar der Rest — denn `{{VersScheinNr}}` und
/// `Versicherungsschein-Nr` erkennt keine Regel als dasselbe, ein Mensch in
/// zwei Klicks schon.
///
/// Gewählt wird immer bewusst: Der Dialog benennt nichts von sich aus um
/// (§1.3 „Vorschlagen statt entscheiden").
class ZuordnungsDialog extends StatelessWidget {
  final String titel;
  final String einleitung;

  /// Sortierte Vorschläge; [ZuordnungsVorschlag.tauschtWaise] wandert unten in
  /// den Befund statt in die Auswahl.
  final List<ZuordnungsVorschlag> vorschlaege;

  /// Kandidaten ohne erkannten Zusammenhang — von Hand wählbar.
  final List<String> uebrige;

  /// Beschriftung für „neues Feld anlegen"; null, wenn es diesen Weg nicht
  /// gibt (einen Platzhalter kann die App nicht erfinden).
  final String? neuAnlegen;

  const ZuordnungsDialog({
    super.key,
    required this.titel,
    required this.einleitung,
    required this.vorschlaege,
    this.uebrige = const [],
    this.neuAnlegen,
  });

  /// Fragt für einen **Platzhalter ohne Feld**, ob ein vorhandenes Feld
  /// umbenannt werden soll, statt ein zweites anzulegen.
  ///
  /// Zur Auswahl stehen nur Felder, die heute **nichts** treffen: Ein Feld
  /// umzubenennen, das in einer der Word-Dateien ankommt, tauschte nur den
  /// einen Waisen gegen den anderen ([allePlatzhalter] sagt, welche das sind).
  ///
  /// Gibt es weder Vorschlag noch freien Kandidaten, gibt es auch nichts zu
  /// fragen: Dann lautet die Antwort sofort [NeuesFeldAnlegen] — kein Dialog
  /// vor jedem Chip.
  static Future<ZuordnungsWahl?> fuerPlatzhalter(
    BuildContext context, {
    required String platzhalter,
    required Iterable<String?> feldnamen,
    required Iterable<String> allePlatzhalter,
  }) {
    final vorschlaege = PlatzhalterZuordnung.vorschlaege(
      platzhalter,
      feldnamen,
      belegtePlatzhalter: allePlatzhalter,
    );
    final belegt = {
      for (final name in allePlatzhalter) name.trim().toLowerCase(),
    };
    final gesehen = {
      platzhalter.trim().toLowerCase(),
      for (final vorschlag in vorschlaege) vorschlag.name.trim().toLowerCase(),
    };
    final uebrige = <String>[];
    for (final name in feldnamen) {
      final kandidat = name?.trim();
      if (kandidat == null || kandidat.isEmpty) continue;
      final klein = kandidat.toLowerCase();
      if (belegt.contains(klein) || !gesehen.add(klein)) continue;
      uebrige.add(kandidat);
    }

    if (vorschlaege.isEmpty && uebrige.isEmpty) {
      return Future.value(const NeuesFeldAnlegen());
    }
    return _zeige(
      context,
      ZuordnungsDialog(
        titel: 'Platzhalter {{$platzhalter}} zuordnen',
        einleitung:
            'Dieser Platzhalter hat kein Feld — er bliebe beim Erzeugen roh '
            'im Dokument stehen. Ein vorhandenes Feld umbenennen, statt ein '
            'zweites anzulegen?',
        vorschlaege: vorschlaege,
        uebrige: uebrige,
        neuAnlegen: 'Neues Feld anlegen',
      ),
    );
  }

  /// Fragt für ein **Feld ohne Platzhalter**, welchen offenen Platzhalter es
  /// künftig meinen soll. [offenePlatzhalter] sind die, die heute kein Feld
  /// haben — ein belegter wäre ein doppelter Name.
  static Future<ZuordnungsWahl?> fuerFeld(
    BuildContext context, {
    required String feldname,
    required List<String> offenePlatzhalter,
  }) {
    final vorschlaege = PlatzhalterZuordnung.vorschlaege(
      feldname,
      offenePlatzhalter,
    );
    final vorgeschlagen = {
      for (final vorschlag in vorschlaege) vorschlag.name.trim().toLowerCase(),
    };
    final uebrige = [
      for (final platzhalter in offenePlatzhalter)
        if (!vorgeschlagen.contains(platzhalter.trim().toLowerCase()))
          platzhalter,
    ];

    return _zeige(
      context,
      ZuordnungsDialog(
        titel: 'Feld "$feldname" zuordnen',
        einleitung:
            'Dieses Feld kommt in keiner der Word-Dateien vor — was hier '
            'eingetragen wird, verwirft die App beim Erzeugen. Welchen '
            'Platzhalter soll es meinen?',
        vorschlaege: vorschlaege,
        uebrige: uebrige,
      ),
    );
  }

  static Future<ZuordnungsWahl?> _zeige(
    BuildContext context,
    ZuordnungsDialog dialog,
  ) {
    return showDialog<ZuordnungsWahl>(context: context, builder: (_) => dialog);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auswahl = [
      for (final vorschlag in vorschlaege)
        if (!vorschlag.tauschtWaise) vorschlag,
    ];
    final befunde = [
      for (final vorschlag in vorschlaege)
        if (vorschlag.tauschtWaise) vorschlag.name,
    ];

    return AlertDialog(
      title: Text(titel),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Text(einleitung, style: theme.textTheme.bodyMedium),
              for (final vorschlag in auswahl) _vorschlag(context, vorschlag),
              if (uebrige.isNotEmpty) _uebrigeListe(context),
              if (befunde.isNotEmpty) _befund(context, befunde),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        if (neuAnlegen case final beschriftung?)
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(const NeuesFeldAnlegen()),
            child: Text(beschriftung),
          ),
      ],
    );
  }

  Widget _vorschlag(BuildContext context, ZuordnungsVorschlag vorschlag) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        vorschlag.guete == ZuordnungsGuete.schreibweise
            ? Icons.spellcheck
            : Icons.link,
        color: theme.colorScheme.primary,
      ),
      title: Text(vorschlag.name),
      subtitle: Text(vorschlag.guete.erklaerung),
      trailing: Text(
        vorschlag.guete.anzeige,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
      onTap: () => Navigator.of(context).pop(NamenUebernehmen(vorschlag.name)),
    );
  }

  /// Der Rest, eingeklappt: Er ist lang und meist nicht gemeint — aber er ist
  /// der einzige Weg für Namenspaare, die keine Regel als verwandt erkennt.
  Widget _uebrigeListe(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Anderen Namen wählen (${uebrige.length})'),
      children: [
        for (final name in uebrige)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 16),
            title: Text(name),
            onTap: () => Navigator.of(context).pop(NamenUebernehmen(name)),
          ),
      ],
    );
  }

  /// Kandidaten, die heute schon irgendwo ankommen: Sie stehen als Befund da,
  /// nicht als Angebot — umbenannt tauschten sie nur den einen Waisen gegen
  /// den anderen.
  Widget _befund(BuildContext context, List<String> namen) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.error),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Nicht umbenennen: ${namen.join(', ')} — dieser Name kommt bereits in '
        'einer der Word-Dateien an. Die beiden Dateien nennen dieselbe Angabe '
        'verschieden; ein Feld kann nur einen der Namen tragen. Das gehört in '
        'Word geradegezogen.',
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
