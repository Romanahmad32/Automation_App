import 'package:automation_app/features/form_template_setup/domain/services/gespeicherter_stand.dart';
import 'package:automation_app/features/form_template_setup/presentation/widgets/auflistung_badge.dart';
import 'package:flutter/material.dart';

/// Das Kennzeichen „unvollständig" in der Vorlagenübersicht (#104 Stufe 4).
///
/// Bis hierher sah der Anwalt einer Vorlage in der Liste nicht an, ob sie
/// fertig eingerichtet ist — er musste sie öffnen. Die Karte im Editor
/// (`VorlagenStandKarte`) sagt es, aber erst nach dem Klick; die Übersicht
/// zeigt jetzt dieselbe Aussage, so weit sie ohne die Word-Dateien reicht.
///
/// **Es wird hier nichts gerechnet.** Angezeigt wird genau der Stand, den der
/// Editor beim Speichern mitgeschrieben hat ([GespeicherterStand]); eine
/// zweite Rechnung neben `VorlagenStand` wäre die eine Sache, die #104
/// beseitigt hat. Fehlt der Eintrag (Bestand von vor Stufe 4), steht dort
/// **„Noch nicht geprüft"** und ausdrücklich nicht „unvollständig": Über eine
/// Vorlage, die nie gerechnet wurde, ist nichts bekannt.
///
/// Die Gestalt kommt von [AuflistungBadge], dem Badge der Nachbarspalte —
/// derselbe `SoftTone`, dieselbe Höhe, nur mit Zeichen davor. Er kürzt seinen
/// Text notfalls, statt die Spalte zu sprengen (Issue #57).
class VorlagenStandKennzeichen extends StatelessWidget {
  /// Der mitgespeicherte Stand — null heißt unbekannt.
  final GespeicherterStand? stand;

  const VorlagenStandKennzeichen({super.key, required this.stand});

  @override
  Widget build(BuildContext context) {
    final farben = Theme.of(context).colorScheme;
    final aktuell = stand;

    final (text, zeichen, farbe, erklaerung) = switch (aktuell) {
      null => (
        'Noch nicht geprüft',
        Icons.help_outline,
        farben.outline,
        'Diese Vorlage wurde noch nicht im Editor gespeichert, seit die App '
            'den Stand mitschreibt. Einmal öffnen und speichern genügt.',
      ),
      GespeicherterStand(vollstaendig: true) => (
        'Vollständig',
        Icons.check_circle_outline,
        farben.primary,
        'Mindestens eine Word-Datei ist verknüpft, und jeder Platzhalter '
            'darin hat ein Feld.',
      ),
      _ => (
        _mangelText(aktuell.offen),
        Icons.warning_amber_rounded,
        farben.error,
        aktuell.offen == 0
            ? 'Dieser Vorlage fehlt noch eine Word-Datei.'
            : 'Beim letzten Speichern waren ${aktuell.offen} Einträge offen '
                  '— Platzhalter ohne Feld und Felder ohne Vorkommen.',
      ),
    };

    return Tooltip(
      message: erklaerung,
      child: AuflistungBadge(label: text, accent: farbe, icon: zeichen),
    );
  }

  /// „Unvollständig · 3 offen" — ohne Zahl, wenn es keine gibt. Eine Vorlage
  /// ohne Word-Datei hat keine bekannten Platzhalter; „0 offen" daneben läse
  /// sich wie ein Widerspruch zum Wort davor.
  static String _mangelText(int offen) =>
      offen == 0 ? 'Unvollständig' : 'Unvollständig · $offen offen';
}
