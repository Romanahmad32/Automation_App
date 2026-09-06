import 'dart:math' as math;

import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/presentation/utils/platzhalter_einfuege_ziel.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/ansicht_umschalter.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/betreff_text_felder.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/platzhalter_auswahl.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/vorlagen_hinweise_knopf.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_vorlage_vorschau.dart';
import 'package:flutter/material.dart';

/// Anlegen und Ändern einer Mail-Textvorlage (§4.7). Liefert beim Speichern
/// die bearbeitete Vorlage zurück; `null` heisst abgebrochen.
///
/// Der Dialog **speichert nicht selbst**: Ob das Backend die Vorlage annimmt
/// (der Name kann vergeben sein), weiss erst der Aufrufer — er hält den Dialog
/// offen und zeigt die Meldung, statt ihn zu schliessen und den Anwalt vor
/// einer Liste ohne seine Eingabe stehen zu lassen.
///
/// **Dieselben Bausteine wie der Versanddialog** (§4.7, neu geordnet am
/// 06.09.2026): [BetreffTextFelder] mit sichtbarem Einfügeziel, die offene
/// [PlatzhalterAuswahl] direkt darunter, der Umschalter Bearbeiten ↔ Vorschau
/// und dieselbe `EmailVorschau`. Vorher waren es zwei Fassungen derselben
/// Sache — einmal 640 px ohne Vorschau, einmal bis 1160 px mit.
class MailVorlageDialog extends StatefulWidget {
  final MailVorlage vorlage;

  /// Speichert und meldet, ob es geklappt hat.
  final Future<bool> Function(MailVorlage) onSpeichern;

  const MailVorlageDialog({
    super.key,
    required this.vorlage,
    required this.onSpeichern,
  });

  /// Ab dieser Breite steht die Vorschau dauerhaft neben den Feldern —
  /// dieselbe Überlegung wie im Versanddialog, nur ohne dessen dritte Spalte
  /// an Empfängerangaben.
  static const double zweiSpaltenAb = 1080;

  @override
  State<MailVorlageDialog> createState() => _MailVorlageDialogState();
}

class _MailVorlageDialogState extends State<MailVorlageDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.vorlage.name,
  );
  late final TextEditingController _betreff = TextEditingController(
    text: widget.vorlage.betreff,
  );
  late final TextEditingController _text = TextEditingController(
    text: widget.vorlage.text,
  );

  /// Wohin ein angeklickter Platzhalter geht — und die Auskunft darüber. Ein
  /// Klick auf einen Chip nimmt dem Textfeld den Fokus, die Schreibmarke im
  /// Controller bleibt aber stehen; deshalb führt das Ziel eigene Fokusknoten.
  late final PlatzhalterEinfuegeZiel _ziel = PlatzhalterEinfuegeZiel(
    betreff: _betreff,
    text: _text,
  );

  VersandAnsicht _ansicht = VersandAnsicht.bearbeiten;

  bool _speichert = false;

  /// Was am Pflichtfeld „Name" fehlt; null heisst: nichts. Steht als
  /// `errorText` am Feld — vorher kehrte [_speichern] bei leerem Namen
  /// wortlos um, und der Knopf sah kaputt aus (behoben am 03.09.2026).
  String? _fehler;

  @override
  void dispose() {
    _ziel.dispose();
    _name.dispose();
    _betreff.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(
        () => _fehler = 'Ohne Namen ist die Vorlage später nicht zu finden.',
      );
      return;
    }

    setState(() {
      _speichert = true;
      _fehler = null;
    });
    final geglueckt = await widget.onSpeichern(
      widget.vorlage.copyWith(
        name: name,
        betreff: _betreff.text.trim(),
        text: _text.text,
      ),
    );
    if (!mounted) return;
    setState(() => _speichert = false);
    if (geglueckt) Navigator.of(context).pop(true);
  }

  Widget _felder() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          onChanged: (_) {
            if (_fehler != null) setState(() => _fehler = null);
          },
          decoration: InputDecoration(
            labelText: 'Name *',
            helperText: 'Danach wählen Sie die Vorlage beim Verfassen aus.',
            errorText: _fehler,
            border: const OutlineInputBorder(),
          ),
        ),
        BetreffTextFelder(
          ziel: _ziel,
          textHilfe:
              'Eine Zeile, in der nur Anrede oder Zusatzgruß stehen und beide '
              'leer bleiben, entfällt ganz. Jeder andere Platzhalter ohne Wert '
              'bleibt als {{…}} stehen und hält den Versand auf. Die Signatur '
              'nicht mit eintippen, die hängt der Versand an.',
        ),
        // Direkt unter dem Nachrichtenfeld und offen: Wer eine Vorlage
        // schreibt, braucht die gültigen Namen im Blick, nicht hinter einem
        // Aufklapper. Die Mängelauskunft, die hier früher stand, sitzt jetzt
        // im „?"-Knopf oben rechts.
        PlatzhalterAuswahl(ziel: _ziel),
      ],
    ),
  );

  Widget _rumpf({required bool nebeneinander}) {
    final vorschau = MailVorlageVorschau(betreff: _betreff, text: _text);
    if (_ansicht == VersandAnsicht.vorschau) return vorschau;
    if (!nebeneinander) return _felder();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: _felder()),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: vorschau),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fenster = MediaQuery.sizeOf(context);
    final nebeneinander = fenster.width >= MailVorlageDialog.zweiSpaltenAb;
    final hoehe = math.max(
      260.0,
      math.min(nebeneinander ? 620.0 : 520.0, fenster.height - 220),
    );

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              widget.vorlage.istGespeichert ? 'Vorlage ändern' : 'Neue Vorlage',
            ),
          ),
          VorlagenHinweiseKnopf(betreff: _betreff, text: _text),
        ],
      ),
      content: SizedBox(
        width: math.min(nebeneinander ? 1040 : 660, fenster.width - 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnsichtUmschalter(
              gewaehlt: _ansicht,
              onWechsel: (ansicht) => setState(() => _ansicht = ansicht),
              hinweis: 'Die Vorschau füllt die Vorlage mit Beispieldaten.',
            ),
            const SizedBox(height: 12),
            // Gedeckelt statt festgesetzt: Ein `SizedBox(height:)` liefe im
            // niedrigen Fenster über den Dialogrand hinaus, und ein
            // Aufklappfenster über dem Rand ist nicht mehr zu bedienen.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: hoehe),
                child: _rumpf(nebeneinander: nebeneinander),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _speichert ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _speichert ? null : _speichern,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
