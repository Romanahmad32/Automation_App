import 'package:automation_app/core/general_classes/datum_format.dart';
import 'package:automation_app/features/mandanten/domain/entities/akten_auswahl_eintrag.dart';
import 'package:flutter/material.dart';

/// Eine Zeile in „Akte zuordnen": der Ordner, und darunter, warum er an dieser
/// Stelle steht. Ein fremd zugeordneter Ordner ist ausgegraut und nicht
/// antippbar — sichtbar bleibt er, sonst suchte der Anwalt ihn und fände ihn
/// nicht.
///
/// Schlank wie `NichtZugeordneterOrdnerKachel`: Die Liste baut sich über rund
/// 4000 Ordner.
class AktenAuswahlKachel extends StatelessWidget {
  final AktenAuswahlEintrag eintrag;
  final VoidCallback onWaehlen;

  const AktenAuswahlKachel({
    super.key,
    required this.eintrag,
    required this.onWaehlen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, farbe) = switch (eintrag.art) {
      AktenAuswahlArt.namensvorschlag => (Icons.folder, scheme.primary),
      AktenAuswahlArt.offen => (Icons.folder_outlined, null),
      AktenAuswahlArt.ohneMandantenbezug => (Icons.folder_off_outlined, null),
      AktenAuswahlArt.fremdZugeordnet => (Icons.lock_outline, null),
    };
    return ListTile(
      dense: true,
      enabled: eintrag.waehlbar,
      leading: Icon(icon, color: eintrag.waehlbar ? farbe : null),
      title: Text(eintrag.akte.ordnername),
      subtitle: Text(untertitel(eintrag)),
      onTap: eintrag.waehlbar ? onWaehlen : null,
    );
  }

  /// Warum der Ordner hier steht — öffentlich, damit der Test den Wortlaut
  /// nicht aus dem Widgetbaum fischen muss.
  static String untertitel(AktenAuswahlEintrag eintrag) {
    final akte = eintrag.akte;
    final geaendert = akte.geaendertAm == null
        ? ''
        : ' · geändert am ${deutschesDatum(akte.geaendertAm!)}';
    return switch (eintrag.art) {
      AktenAuswahlArt.namensvorschlag =>
        'Passt zum Namen${eintrag.vermerkt ? ' · beiseitegelegt' : ''}'
            '$geaendert',
      AktenAuswahlArt.offen => '${akte.aktentyp.bezeichnung}$geaendert',
      AktenAuswahlArt.ohneMandantenbezug =>
        'Beiseitegelegt — die Zuordnung nimmt den Vermerk zurück',
      AktenAuswahlArt.fremdZugeordnet =>
        'Gehört bereits einem anderen Mandanten',
    };
  }
}
