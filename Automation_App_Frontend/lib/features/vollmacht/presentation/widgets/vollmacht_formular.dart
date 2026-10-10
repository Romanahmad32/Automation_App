import 'package:automation_app/core/dateien/datei_oeffner.dart';
import 'package:automation_app/features/vollmacht/domain/entities/vollmacht_art.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_art_auswahl.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_hinweis.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_kopf_felder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Eingabeteil des Vollmacht-Dialogs (§4.11): Vorlagenart, die Hinweise,
/// die vor dem Druck zählen, und die vorbelegten Kopfzeilen.
class VollmachtFormular extends StatelessWidget {
  final VollmachtStand stand;

  const VollmachtFormular({super.key, required this.stand});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VollmachtCubit>();
    final gesperrt = stand.phase != VollmachtPhase.eingabe;
    final art = stand.art;
    final vorlagen = stand.vorlagen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        VollmachtArtAuswahl(
          art: art,
          rechtsgebiet: stand.vorgang?.rechtsgebiet ?? '',
          onGewaehlt: gesperrt ? null : cubit.waehleArt,
        ),
        if (stand.vorlageFehlt && art != null && vorlagen != null)
          VollmachtHinweis(
            icon: Icons.find_in_page_outlined,
            text:
                'Die Vorlage „${vorlagen.zu(art)?.dateiname ?? art.titel}“ '
                'liegt nicht im Ordner ${vorlagen.ordner}. Legen Sie die Datei '
                'dort ab und prüfen Sie erneut.',
            aktionen: [
              TextButton(
                onPressed: () => DateiOeffner.oeffneOrdner(vorlagen.ordner),
                child: const Text('Ordner öffnen'),
              ),
              TextButton(
                onPressed: cubit.pruefeVorlagen,
                child: const Text('Erneut prüfen'),
              ),
            ],
          ),
        if (_mandantText(stand.mandantLage) case final text?)
          VollmachtHinweis(icon: Icons.person_off_outlined, text: text),
        VollmachtKopfFelder(
          kopfdaten: stand.kopfdaten,
          art: art,
          gesperrt: gesperrt,
          onGeaendert: cubit.aendereKopfdaten,
        ),
        if (art == VollmachtArt.bussgeldsachen)
          const VollmachtHinweis(
            icon: Icons.event_busy_outlined,
            text:
                'Das Tatdatum kennt die App nicht — bitte hinter „am“ '
                'ergänzen oder auf dem Papier eintragen.',
          ),
        if (art == VollmachtArt.unfallsachen)
          const VollmachtHinweis(
            icon: Icons.account_balance_outlined,
            text:
                'Die Bankverbindung bleibt für den Mandanten frei und wird '
                'nicht gespeichert.',
          ),
      ],
    );
  }

  static String? _mandantText(VollmachtMandantLage lage) => switch (lage) {
    VollmachtMandantLage.geladen => null,
    VollmachtMandantLage.keinerZugeordnet =>
      'Dem Vorgang ist kein Mandant zugeordnet — die Felder sind deshalb '
          'leer. Bitte hier eintragen oder den Mandanten am Vorgang zuordnen.',
    VollmachtMandantLage.nichtGefunden =>
      'Der zugeordnete Mandant ließ sich nicht aus dem Register laden — die '
          'Felder sind deshalb leer. Bitte hier eintragen.',
  };
}
