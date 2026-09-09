import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/sachgebiete/domain/entities/sachgebiet.dart';
import 'package:automation_app/features/sachgebiete/domain/services/abteilung_kuerzel.dart';
import 'package:automation_app/features/sachgebiete/domain/services/rechtsgebiet_ableitung.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/abteilung_auswahl.dart';
import 'package:automation_app/features/sachgebiete/presentation/widgets/sachgebiet_katalog_builder.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:flutter/material.dart';

/// Das Rechtsgebiet eines Vorgangs — **abgeleitet aus der Abteilung** (§7.1),
/// nicht ein zweites Mal ausgewählt.
///
/// Abteilung und Rechtsgebiet sind dieselbe Katalogzeile, einmal als Kürzel
/// (`C03`) und einmal als Name („Verkehrsrecht"). Vorher standen sie als zwei
/// gleichrangige Auswahllisten untereinander in derselben Karte: dieselben
/// zwölf Einträge, zwei Beschriftungen, und **keine Verbindung**. Wer die
/// Abteilung auf `C05` stellte, behielt „Verkehrsrecht" — mit einer falschen
/// Zeile im Register (§6.2), Pflicht-Unfallfeldern und einem Kennzeichen in
/// der Referenz (§4.2), das dort nichts zu suchen hat. Niemand sagte etwas.
///
/// Deshalb zeigt das Feld im Regelfall nur noch **an**, was aus der Abteilung
/// folgt. Eine Abweichung bleibt möglich ([onAbweichend]) — dann wird daraus
/// die volle Auswahl über den Katalog, wie §7.1 sie verlangt, und sie bleibt
/// stehen, bis der Anwalt sie zurücknimmt ([onFolgtWieder]). Dasselbe Muster
/// wie bei der Referenz-Vorschau der Nachbarkarte: automatisch, bis von Hand
/// eingegriffen wird, und mit sichtbarem Weg zurück.
class RechtsgebietAuswahl extends StatelessWidget {
  /// Der aktuell geltende Wert — abgeleitet oder von Hand gewählt.
  final String rechtsgebiet;

  /// Die Abteilung, aus der abgeleitet wird (roher Formularwert, z. B.
  /// `C05/3`); maßgeblich ist ihr Hauptteil.
  final String abteilung;

  /// Ob der Anwalt das Rechtsgebiet von Hand gesetzt hat. Dann folgt es der
  /// Abteilung nicht mehr, und die Auswahl bleibt offen stehen.
  final bool manuell;

  final ValueChanged<String> onChanged;

  /// „Abweichend wählen" — schaltet von der Anzeige auf die Auswahl um.
  final VoidCallback onAbweichend;

  /// Zurück zur Ableitung aus der Abteilung.
  final VoidCallback onFolgtWieder;

  const RechtsgebietAuswahl({
    super.key,
    required this.rechtsgebiet,
    required this.abteilung,
    required this.manuell,
    required this.onChanged,
    required this.onAbweichend,
    required this.onFolgtWieder,
  });

  /// Was bei „Verkehrsrecht" zusätzlich passiert — der Satz gehört an beide
  /// Ausprägungen, denn er erklärt, warum die Karte darunter erscheint.
  static const String _verkehrsrechtHinweis =
      'Bei „Verkehrsrecht" werden Unfall- und Zentralruf-Felder eingeblendet.';

  String get _haupt => AbteilungKuerzel.zerlege(abteilung).haupt;

  @override
  Widget build(BuildContext context) {
    return SachgebietKatalogBuilder(
      builder: (context, katalog) {
        final abgeleitet = RechtsgebietAbleitung.zuAbteilung(
          katalog,
          abteilung,
        );
        // Ohne Katalogtreffer gibt es nichts abzuleiten (Abteilung leer oder
        // ausserhalb des Katalogs) — dann ist die Auswahl der einzige Weg,
        // und sie steht sofort offen statt hinter einem Knopf.
        if (manuell || abgeleitet == null) {
          return _auswahl(context, katalog, abgeleitet);
        }
        return _anzeige(context, abgeleitet);
      },
    );
  }

  /// Der Regelfall: eine Zeile, die zeigt, was aus der Abteilung folgt.
  Widget _anzeige(BuildContext context, String abgeleitet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Rechtsgebiet',
              border: const OutlineInputBorder(),
              helperText:
                  'Ergibt sich aus dem Hauptsachgebiet $_haupt. '
                  '$_verkehrsrechtHinweis',
              helperMaxLines: 3,
            ),
            child: Text(RechtsgebietWert.anzeige(abgeleitet)),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          // Auf die Höhe des Feldes daneben, nicht auf die seiner Hilfszeile.
          padding: const EdgeInsets.only(top: 8),
          child: TextButton(
            onPressed: onAbweichend,
            child: const Text('Abweichend wählen'),
          ),
        ),
      ],
    );
  }

  /// Die volle Auswahl über den Katalog (§7.1) — nach „Abweichend wählen",
  /// oder wenn sich aus der Abteilung nichts ableiten lässt.
  Widget _auswahl(
    BuildContext context,
    List<Sachgebiet> katalog,
    String? abgeleitet,
  ) {
    final auswahl = SearchableDropdown<String>(
      value: _gewaehlterEintrag(katalog),
      labelText: 'Rechtsgebiet',
      hintText: 'Rechtsgebiet suchen oder auswählen',
      helperText: abgeleitet == null
          ? 'Zur Abteilung ${_haupt.isEmpty ? '(keine)' : _haupt} gibt es '
                'keinen Katalogeintrag — bitte wählen. $_verkehrsrechtHinweis'
          : 'Von Hand gewählt — folgt nicht mehr dem Hauptsachgebiet $_haupt. '
                '$_verkehrsrechtHinweis',
      helperMaxLines: 3,
      entries: _eintraege(katalog),
      onChanged: (gebiet) => onChanged(gebiet ?? rechtsgebiet),
    );
    // Der Weg zurück steht nur, wo es etwas zurückzunehmen gibt.
    if (!manuell || abgeleitet == null) return auswahl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: auswahl),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Wieder dem Hauptsachgebiet $_haupt folgen',
            onPressed: onFolgtWieder,
          ),
        ),
      ],
    );
  }

  /// Der Katalogeintrag, der dem aktuellen Wert entspricht. Verglichen wird
  /// über [RechtsgebietWert.gleich] — ein Altbestandswert (`verkehrsrecht`)
  /// meint denselben Katalogeintrag wie `Verkehrsrecht`.
  String? _gewaehlterEintrag(List<Sachgebiet> katalog) {
    for (final sachgebiet in katalog) {
      if (RechtsgebietWert.gleich(
        sachgebiet.rechtsgebietVorschlag,
        rechtsgebiet,
      )) {
        return sachgebiet.rechtsgebietVorschlag;
      }
    }
    return rechtsgebiet.isEmpty ? null : rechtsgebiet;
  }

  /// Der Katalog als Auswahleinträge. Ein gespeicherter Wert ausserhalb des
  /// Katalogs (Altbestand wie „Vertragsrecht", §7.1) kommt als eigener
  /// Eintrag dazu, statt still aus der Anzeige zu fallen — dieselbe Regel wie
  /// beim Kürzel in [AbteilungAuswahl].
  List<SearchableDropdownEntry<String>> _eintraege(List<Sachgebiet> katalog) {
    final eintraege = <SearchableDropdownEntry<String>>[];
    final bekannt = <String>{};
    for (final sachgebiet in katalog) {
      final wert = sachgebiet.rechtsgebietVorschlag;
      // Zwei Kürzel können auf dasselbe Sachgebiet zeigen; im Dropdown steht
      // es trotzdem nur einmal (wie in `RegisterFilter.rechtsgebiete`).
      if (bekannt.add(RechtsgebietWert.normalisiert(wert))) {
        eintraege.add(SearchableDropdownEntry(value: wert, label: wert));
      }
    }
    if (rechtsgebiet.isNotEmpty &&
        bekannt.add(RechtsgebietWert.normalisiert(rechtsgebiet))) {
      eintraege.add(
        SearchableDropdownEntry(
          value: rechtsgebiet,
          label: '$rechtsgebiet — nicht im Katalog',
        ),
      );
    }
    return eintraege;
  }
}
