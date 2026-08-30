import 'package:automation_app/core/general_widgets/form/general_text_field.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/settings/domain/services/synchronisierter_ordner.dart';
import 'package:automation_app/features/settings/presentation/widgets/ordner_auswahl_feld.dart';
import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Die Einstellungen des Register-Spiegels (§6.2): wohin, unter welchem Namen,
/// wann und mit welchem Inhalt.
///
/// Der Ablageordner ist ein gewöhnlicher Ordner. Liegt er im synchronisierten
/// Bereich, ist das Register unterwegs lesbar — die App selbst weiß davon
/// nichts. Genau deshalb steht der OneDrive-Pfad hier nur als *Vorschlag*: Er
/// spart das Suchen im Dialog, mehr nicht.
class RegisterAblageFelder extends StatelessWidget {
  const RegisterAblageFelder({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const OrdnerAuswahlFeld(
        formControlName: 'registerAblageOrdner',
        beschriftung: 'Register-Ablage',
        dialogTitel: 'Ordner für das Register wählen',
        icon: Icons.cloud_outlined,
        hinweisOhneOrdner:
            'Ohne Ablageordner wird keine Register-Datei geschrieben. Ein Ordner '
            'im synchronisierten Bereich macht das Register unterwegs lesbar.',
      ),
      const SizedBox(height: 8),
      const RegisterAblageVorschlag(),
      const SizedBox(height: 16),
      const GeneralTextField<String>(
        formControlName: 'registerDateiname',
        labelText: 'Dateiname (ohne Endung)',
        inputDecoration: InputDecoration(
          hintText: KanzleiSettings.defaultRegisterDateiname,
          prefixIcon: Icon(Icons.description_outlined),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Daraus entstehen die Word- und die PDF-Fassung. Ein eigener Name ist '
        'Absicht: Das bisherige Register-Dokument der Kanzlei bleibt daneben '
        'unangetastet liegen.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      const SizedBox(height: 16),
      ReactiveSwitchListTile(
        formControlName: 'registerNachAbschlussSchreiben',
        title: const Text('Nach jedem Abschluss neu schreiben'),
        subtitle: const Text(
          'Sonst nur auf Knopfdruck im Register. Ein Fehlschlag dabei kann '
          'einen abgeschlossenen Vorgang nie rückgängig machen.',
        ),
        contentPadding: EdgeInsets.zero,
      ),
      const SizedBox(height: 8),
      ReactiveDropdownField<String>(
        formControlName: 'registerExportFilter',
        // Ohne das bestimmt der längste Eintrag die Mindestbreite des Feldes,
        // und das Formular läuft auf schmalen Fenstern seitlich heraus.
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Inhalt der Datei',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.filter_alt_outlined),
        ),
        items: const [
          DropdownMenuItem(
            value: KanzleiSettings.registerFilterAlle,
            child: Text('Alle Vorgänge'),
          ),
          DropdownMenuItem(
            value: KanzleiSettings.registerFilterAbgeschlossen,
            child: Text('Nur abgeschlossene Vorgänge'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Bewusst hier und nicht im Register: Der Filter dort wirkt nur auf den '
        'Bildschirm. Sonst hinge der Inhalt einer Datei, die andere lesen, '
        'davon ab, was zuletzt eingestellt war.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    ],
  );
}

/// Bietet den erkannten synchronisierten Ordner mit einem Klick an. Erscheint
/// nur, solange nichts eingetragen ist und ein solcher Ordner gefunden wurde.
class RegisterAblageVorschlag extends StatelessWidget {
  const RegisterAblageVorschlag({super.key});

  @override
  Widget build(BuildContext context) {
    final vorschlag = SynchronisierterOrdner.vorschlag();
    if (vorschlag == null) return const SizedBox.shrink();

    return ReactiveValueListenableBuilder<String>(
      formControlName: 'registerAblageOrdner',
      builder: (context, control, _) {
        if ((control.value ?? '').trim().isNotEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        // Der Pfad steht bewusst unter dem Knopf und nicht in seiner
        // Beschriftung: Ein Benutzerprofil mit langem Namen macht daraus sonst
        // eine Zeile, die aus dem Formular herausläuft.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => control.value = vorschlag,
              icon: const Icon(Icons.cloud_sync_outlined, size: 18),
              label: const Text('Erkannten OneDrive-Ordner übernehmen'),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                vorschlag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
