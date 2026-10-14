import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_fehler_art.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierung_cubit.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_ansicht.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_dialog_phase.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_fortschritt.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/aktualisierungs_stand_zeile.dart';
import 'package:automation_app/core/aktualisierung/presentation/widgets/selbst_herunterladen_knopf.dart';
import 'package:automation_app/core/general_widgets/hinweis_zeile.dart';
import 'package:automation_app/core/general_widgets/schritt_anzeige.dart';
import 'package:material_ui/material_ui.dart';

/// Der Inhalt des Dialogs „App aktualisieren“ je Zustand (2a–2e der
/// abgenommenen Vorschau, #196). Die Texte stehen dort in der Tabelle „Alle
/// Texte“ und sind wörtlich übernommen.
///
/// Die Schrittanzeige steht in jedem Zustand an derselben Stelle, gleich
/// unter der Kopfzeile — damit der Anwalt sieht, wo er ist.
class AktualisierungsDialogInhalt extends StatelessWidget {
  /// „Jetzt aktualisieren“ (2a) — lädt; im echten Betrieb von GitHub.
  static const Key jetztAktualisierenSchluessel = ValueKey(
    'aktualisierung-jetzt-aktualisieren',
  );

  static const List<String> schritte = [
    'Herunterladen',
    'Neu starten',
    'Fertig',
  ];

  static const String datenBleiben =
      'Ihre Vorgänge, Mandanten, Vorlagen und Einstellungen bleiben erhalten.';

  const AktualisierungsDialogInhalt({
    required this.ansicht,
    required this.cubit,
    super.key,
  });

  final AktualisierungsAnsicht ansicht;
  final AktualisierungCubit cubit;

  @override
  Widget build(BuildContext context) {
    final stand = ansicht.stand;
    final version = stand?.neueVersion ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: switch (ansicht.dialogPhase) {
        AktualisierungsDialogPhase.verfuegbar => _verfuegbar(context, version),
        AktualisierungsDialogPhase.laedt => _laedt(context, stand!, version),
        AktualisierungsDialogPhase.bereit => _bereit(context, version),
        AktualisierungsDialogPhase.fehler => _fehler(context, stand!, version),
        AktualisierungsDialogPhase.schliesst => _schliesst(context),
        AktualisierungsDialogPhase.ohneUpdate => [
          AktualisierungsStandZeile(ansicht: ansicht),
        ],
      },
    );
  }

  /// 2a — ein großer Hauptknopf, darunter die Zusage, dass nichts blockiert.
  List<Widget> _verfuegbar(BuildContext context, String version) {
    final theme = Theme.of(context);
    return [
      _kopf(context, 'Version $version ist verfügbar.'),
      const SchrittAnzeige(schritte: schritte),
      _datenBleiben(context),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: FilledButton.icon(
          key: jetztAktualisierenSchluessel,
          onPressed: ansicht.arbeitet ? null : cubit.herunterladen,
          icon: const Icon(Icons.download),
          label: const Text('Jetzt aktualisieren'),
        ),
      ),
      Text(
        'Das Herunterladen läuft im Hintergrund – Sie können dabei '
        'weiterarbeiten.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  /// 2b — Fortschritt und der Satz, dass das Fenster zugehen darf.
  List<Widget> _laedt(
    BuildContext context,
    AktualisierungsStand stand,
    String version,
  ) => [
    _kopf(context, 'Version $version wird heruntergeladen.'),
    const SchrittAnzeige(schritte: schritte, aktiv: 0),
    AktualisierungsFortschritt(stand: stand),
    const HinweisZeile(
      symbol: Icons.info_outline,
      text:
          'Sie können weiterarbeiten. Dieses Fenster lässt sich schließen. '
          'Den Stand sehen Sie auch unten in der Seitenleiste.',
    ),
  ];

  /// 2c — was beim Neustart passiert, bevor er passiert.
  List<Widget> _bereit(BuildContext context, String version) {
    final theme = Theme.of(context);
    return [
      _kopf(context, 'Version $version ist bereit.'),
      const SchrittAnzeige(schritte: schritte, erledigt: 1, aktiv: 1),
      Text(
        'Die App wird kurz geschlossen und startet von selbst neu '
        '(ca. 1 Minute).',
        style: theme.textTheme.bodyMedium,
      ),
      HinweisZeile(
        symbol: Icons.save_outlined,
        text: 'Bitte speichern Sie offene Eingaben vorher.',
        farbe: theme.colorScheme.tertiary,
        textfarbe: theme.colorScheme.onSurface,
      ),
      _datenBleiben(context),
    ];
  }

  /// 2d — ruhig statt rot: Ursache, Entwarnung, Rückfallweg.
  ///
  /// Die Überschrift folgt der Ursache: Leitung und Prüfung gehören zum
  /// Herunterladen. Bei `sonstig` (auch ohne `fehlerArt`, wie in [_ursache])
  /// kann es ebenso der Start des Installationsprogramms gewesen sein — dann
  /// stimmte „konnte nicht heruntergeladen werden“ nicht.
  List<Widget> _fehler(
    BuildContext context,
    AktualisierungsStand stand,
    String version,
  ) {
    final adresse = stand.downloadUrl;
    final beimLaden = switch (stand.fehlerArt) {
      AktualisierungsFehlerArt.verbindung ||
      AktualisierungsFehlerArt.pruefung => true,
      AktualisierungsFehlerArt.sonstig || null => false,
    };
    return [
      _kopf(
        context,
        beimLaden
            ? 'Version $version konnte nicht heruntergeladen werden.'
            : 'Die Aktualisierung auf Version $version hat nicht geklappt.',
      ),
      const SchrittAnzeige(schritte: schritte),
      _ursache(stand),
      HinweisZeile(
        symbol: Icons.verified_user_outlined,
        text:
            'Es wurde nichts verändert. Sie können wie gewohnt '
            'weiterarbeiten.',
        farbe: Theme.of(context).colorScheme.primary,
      ),
      if (adresse != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SelbstHerunterladenKnopf(adresse: adresse),
        ),
    ];
  }

  /// 2e — ohne Knöpfe, bis die App zugeht.
  List<Widget> _schliesst(BuildContext context) {
    final theme = Theme.of(context);
    return [
      _kopf(context, 'Die App wird jetzt geschlossen …'),
      const SchrittAnzeige(schritte: schritte, erledigt: 1, aktiv: 1),
      LinearProgressIndicator(
        minHeight: 4,
        borderRadius: BorderRadius.circular(2),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      Text(
        'Sie startet in etwa einer Minute von selbst wieder – Sie müssen '
        'nichts tun.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      // Leise: der Ausweg, falls der Neustart ausbleibt — ohne dass er wie
      // eine Aufgabe aussieht.
      Text(
        'Falls die App nach zwei Minuten nicht wieder da ist, öffnen Sie sie '
        'wie gewohnt über das Symbol.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }

  /// Die zwei häufigen Ursachen mit eigenem kurzen Satz; sonst — auch ohne
  /// `fehlerArt` — der Satz des Dienstes (siehe `AktualisierungsFehlerArt`).
  Widget _ursache(AktualisierungsStand stand) =>
      switch (stand.fehlerArt ?? AktualisierungsFehlerArt.sonstig) {
        AktualisierungsFehlerArt.verbindung => const HinweisZeile(
          symbol: Icons.cloud_off,
          text: 'Meist fehlt nur kurz die Internetverbindung.',
        ),
        AktualisierungsFehlerArt.pruefung => const HinweisZeile(
          symbol: Icons.file_download_off_outlined,
          text: 'Die Datei kam nicht vollständig an und wird nicht verwendet.',
        ),
        AktualisierungsFehlerArt.sonstig => HinweisZeile(
          symbol: Icons.info_outline,
          text: stand.meldung ?? '',
        ),
      };

  Widget _kopf(BuildContext context, String text) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);

  Widget _datenBleiben(BuildContext context) => HinweisZeile(
    symbol: Icons.verified_user_outlined,
    text: datenBleiben,
    farbe: Theme.of(context).colorScheme.primary,
  );
}
