import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierung_builder.dart';
import 'package:automation_app/core/general_widgets/aktualisieren_button.dart';
import 'package:automation_app/core/general_widgets/anwendungs_info.dart';
import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/settings/presentation/widgets/einstellungen_reiter.dart';
import 'package:material_ui/material_ui.dart';

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
      builder: (context, ansicht) {
        return EinstellungenReiter(
          links: [
            FormSection(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle:
                  'Welche Fassung der Anwendung auf diesem Rechner läuft. '
                  'Nennen Sie diese Nummer bei Rückfragen.',
              children: [
                AnwendungsInfo(ansicht: ansicht),
                if (ansicht?.updateInSicht ?? false)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AktualisierenButton(),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
