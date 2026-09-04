import 'package:automation_app/core/aktualisierung/aktualisierung_builder.dart';
import 'package:automation_app/core/general_widgets/anwendungs_info.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/update_herunterladen_button.dart';
import 'package:automation_app/features/settings/presentation/widgets/einstellungen_reiter.dart';
import 'package:flutter/material.dart';

/// Einstellungen-Reiter „Über": welche Version läuft und ob eine neuere
/// bereitsteht.
///
/// Die Seitenleiste zeigt dasselbe, startet aber eingeklappt. Hier sucht ein
/// Windows-Anwender von sich aus danach — und hier ist Platz für den ganzen
/// Satz statt nur einer Nummer.
class UeberSettingsView extends StatelessWidget {
  const UeberSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AktualisierungBuilder(
      builder: (context, stand) {
        final neu = stand?.neueVersion;
        return EinstellungenReiter(
          links: [
            FormSection(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle:
                  'Welche Fassung der Anwendung auf diesem Rechner läuft. '
                  'Nennen Sie diese Nummer bei Rückfragen.',
              children: [
                AnwendungsInfo(stand: stand),
                if (neu != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: UpdateHerunterladenButton(neueVersion: neu),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
