import 'package:automation_app/core/general_widgets/buttons/dropdowns/searchable_dropdown.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:flutter/material.dart';

/// Die drei Felder des Ablagedialogs: Mandant, Akte, Fall-Ordner.
///
/// **Ausgewählt statt getippt** (Korrektur vom 13.09.2026): Akte und Fall sind
/// vorhandene Ordner auf der Platte; sie abzutippen heißt, sich bei jedem
/// Umlaut und jedem Leerzeichen eine neue Ablagestelle anlegen zu können, ohne
/// es zu merken. Dieselben durchsuchbaren Auswahlfelder wie im Speicherschritt
/// des Wizards (`AkteAuswahl`/`UnterordnerAuswahl`) — ohne deren „neu
/// anlegen"-Zweig samt Namensbaukasten: Der gehört an die Stelle, an der ein
/// Fall entsteht, nicht an eine Mail, die in einen bestehenden gelegt wird.
///
/// Das freie Textfeld bleibt als **Rückfall**, wenn es nichts auszuwählen gibt
/// — kein Vorgang erkannt und keine Akte am Mandanten, oder eine Akte ohne
/// Fall-Ordner. Ohne diesen Rückfall wäre der Dialog dann eine Sackgasse.
class PosteingangAktenAblageFelder extends StatelessWidget {
  const PosteingangAktenAblageFelder({
    super.key,
    required this.mandant,
    required this.mandanten,
    required this.onMandant,
    required this.akteController,
    required this.aktenVorschlaege,
    required this.onAkte,
    required this.fallController,
    required this.fallVorschlaege,
    required this.onFall,
    required this.legtAb,
  });

  final Mandant? mandant;
  final List<Mandant> mandanten;
  final ValueChanged<Mandant?> onMandant;

  /// Trägt den gewählten bzw. getippten Namen — beide Wege schreiben hierhin,
  /// damit der Dialog nur eine Quelle für den Wert hat.
  final TextEditingController akteController;
  final List<String> aktenVorschlaege;
  final ValueChanged<String> onAkte;

  final TextEditingController fallController;
  final List<String> fallVorschlaege;
  final ValueChanged<String> onFall;

  final bool legtAb;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<Mandant?>(
          initialValue: mandant,
          decoration: const InputDecoration(
            labelText: 'Mandant',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          items: [
            for (final eintrag in mandanten)
              DropdownMenuItem(
                value: eintrag,
                child: Text(eintrag.anzeigename),
              ),
          ],
          onChanged: legtAb ? null : onMandant,
        ),
        const SizedBox(height: 12),
        _feld(
          controller: akteController,
          vorschlaege: aktenVorschlaege,
          onGewaehlt: onAkte,
          label: 'Akte (Ordner des Mandanten)',
          hinweis: 'Akte suchen oder auswählen',
          icon: Icons.folder_outlined,
        ),
        const SizedBox(height: 12),
        _feld(
          controller: fallController,
          vorschlaege: fallVorschlaege,
          onGewaehlt: onFall,
          label: 'Fall-Ordner (Unterordner)',
          hinweis: 'Fall suchen oder auswählen',
          icon: Icons.topic_outlined,
        ),
      ],
    );
  }

  Widget _feld({
    required TextEditingController controller,
    required List<String> vorschlaege,
    required ValueChanged<String> onGewaehlt,
    required String label,
    required String hinweis,
    required IconData icon,
  }) {
    if (vorschlaege.isEmpty) {
      return TextField(
        controller: controller,
        enabled: !legtAb,
        onChanged: onGewaehlt,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      );
    }
    final wert = controller.text.trim();
    return SearchableDropdown<String>(
      value: vorschlaege.contains(wert) ? wert : null,
      labelText: label,
      hintText: hinweis,
      leadingIcon: Icon(icon),
      entries: [
        for (final name in vorschlaege)
          SearchableDropdownEntry(value: name, label: name),
      ],
      onChanged: (gewaehlt) => onGewaehlt(gewaehlt ?? ''),
    );
  }
}
