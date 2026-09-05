import 'package:automation_app/features/form_template_setup/presentation/widgets/vorlagen_hineinholen_angebot.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Wählt eine Word-Datei und liefert den Pfad, unter dem sie verknüpft werden
/// soll — `null`, wenn nichts gewählt wurde.
typedef VorlagenDateiwahlFunktion =
    Future<String?> Function(BuildContext context);

/// **Der eine** Weg, im Vorlageneditor eine `.docx` auszuwählen: Dateidialog
/// und, wenn die Datei außerhalb des Vorlagenordners liegt, das Angebot, sie
/// hineinzuholen (#33).
///
/// Aus `form_template_details_page.dart` herausgezogen (#104 Stufe 3c). Zwei
/// Gründe: Die Seite steht an ihrem Zeilenbudget, und seit dem Leerzustand
/// (`VorlagenLeerzustand`) führen **zwei** Stellen in dieselbe Wahl — die
/// Karte eines Slots und die Startfläche einer neuen Vorlage.
///
/// [waehle] ist absichtlich ein **veränderliches** Feld und kein fester
/// Verweis: Der Dateidialog ist ein Plattformkanal, den ein Widget-Test nicht
/// bedienen kann, und die Detailseite kann die Wahl nicht als Konstruktor-
/// Parameter annehmen — ihr Konstruktor speist die generierte auto_route-Route
/// (`app_router.gr.dart`), ein zusätzlicher Parameter stünde dort mit drin und
/// verlangte bei jeder Änderung einen build_runner-Lauf. Der Test setzt das
/// Feld und stellt es über [zuruecksetzen] in einem `addTearDown` zurück.
class VorlagenDateiwahl {
  const VorlagenDateiwahl._();

  /// Die im Editor verwendete Dateiwahl — im Test ersetzbar (siehe oben).
  static VorlagenDateiwahlFunktion waehle = ausDateidialog;

  /// Der echte Weg: Dateidialog auf `.docx`, danach das Hineinholen-Angebot.
  ///
  /// Lehnt der Anwalt das Kopieren ab oder liegt die Datei ohnehin im
  /// Vorlagenordner, kommt der gewählte Pfad unverändert zurück.
  static Future<String?> ausDateidialog(BuildContext context) async {
    final ergebnis = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (ergebnis == null || ergebnis.files.isEmpty) return null;
    final gewaehlt = ergebnis.files.first.path;
    if (gewaehlt == null || !context.mounted) return null;
    return VorlagenHineinholenAngebot.bieteAn(context, gewaehlt);
  }

  /// Stellt [waehle] auf den echten Dateidialog zurück — der Weg zurück nach
  /// einem Test.
  static void zuruecksetzen() => waehle = ausDateidialog;
}
