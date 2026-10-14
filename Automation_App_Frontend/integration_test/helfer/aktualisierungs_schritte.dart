import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_dialog_inhalt.dart';
import 'package:automation_app/core/general_widgets/drawer/sidebar_update_hinweis.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bedienung.dart';

/// Die Schritte des Durchlaufs „Update aus der App“ (#196) — nur über die
/// Keys der Knöpfe, wie die Marionette-Tabelle in `test_driver/README.md`
/// sie nennt.
///
/// Im Testmodus liefert der Dienst eine Attrappe (`9.9.9`, eine kleine Datei,
/// rund 2,4 s im Zustand „lädt“) und startet keinen Installer: Er schreibt
/// eine Zeile `aktualisierung-installer` ins Protokoll, und die App bleibt
/// offen (`AktualisierungCubit.testmodus`).
class AktualisierungsSchritte {
  final Bedienung bedienung;

  AktualisierungsSchritte(this.bedienung);

  /// Laden und Prüfen der Attrappe dauern Sekunden, nicht Minuten.
  static const Duration ladeFrist = Duration(seconds: 60);

  /// Die Version, die die Attrappe meldet (`TestmodusAktualisierungsQuelle`).
  static const String version = '9.9.9';

  /// Hinweis in der Seitenleiste antippen — öffnet „App aktualisieren“.
  Future<void> dialogOeffnen() async {
    await bedienung.warteAuf(
      find.byKey(SidebarUpdateHinweis.schluessel),
      frist: ladeFrist,
      was: 'den Update-Hinweis in der Seitenleiste',
    );
    await bedienung.tippe(find.byKey(SidebarUpdateHinweis.schluessel));
    await bedienung.warteAuf(
      find.text('App aktualisieren'),
      was: 'den Dialog „App aktualisieren“',
    );
  }

  /// 2a „Jetzt aktualisieren“ — der Dienst lädt; der Dialog zeigt 2b.
  Future<void> jetztAktualisieren() async {
    await bedienung.tippeAktiv(
      find.byKey(AktualisierungsDialogInhalt.jetztAktualisierenSchluessel),
    );
    await bedienung.warteAuf(
      find.text('Version $version wird heruntergeladen.'),
      was: 'den Fortschritt (2b)',
    );
  }

  /// 2d „Erneut versuchen“ — der Dienst prüft neu und lädt.
  Future<void> erneutVersuchen() => bedienung.tippeAktiv(
    find.byKey(AktualisierungsDialog.erneutVersuchenSchluessel),
  );

  /// Wartet auf 2c „Version 9.9.9 ist bereit.“ und tippt „Jetzt neu starten“.
  Future<void> neuStarten() async {
    await bedienung.warteAuf(
      find.text('Version $version ist bereit.'),
      frist: ladeFrist,
      was: 'die geprüfte Setup-Datei (2c)',
    );
    await bedienung.tippeAktiv(
      find.byKey(AktualisierungsDialog.neuStartenSchluessel),
    );
  }
}
