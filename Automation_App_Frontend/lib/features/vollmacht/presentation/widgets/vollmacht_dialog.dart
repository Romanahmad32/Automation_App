import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/stand_nachziehen.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_cubit.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_katalog_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_dialog_knoepfe.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_formular.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_word_ansicht.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der eine Dialog für die Vollmacht zum Vorgang (§4.11) — erreichbar aus
/// „Vorgang starten" nach dem Speichern und aus jeder Kachel in „Vorgänge".
///
/// Er zeigt die vorbelegten Kopfdaten zur Korrektur, druckt, fällt bei einem
/// gescheiterten Druck auf Word zurück und vermerkt den Druck am Vorgang.
/// Den Ablauf trägt der [VollmachtCubit]; dieser Baustein zeigt nur, wo der
/// gerade steht, und schließt sich, wenn er fertig ist.
class VollmachtDialog extends StatelessWidget {
  const VollmachtDialog({super.key});

  /// Öffnet den Dialog zu [vorgang].
  static Future<void> zeige(BuildContext context, Vorgang vorgang) {
    final katalog = switch (getIt<SachgebietCubit>().state) {
      SachgebietKatalogGeladen(:final eintraege) => eintraege,
      _ => const <Never>[],
    };
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider(
        create: (_) => getIt<VollmachtCubit>()..starte(vorgang, katalog),
        child: const VollmachtDialog(),
      ),
    );
  }

  /// Öffnet den Dialog zum Vorgang mit [referenz] — für Stellen, die nur die
  /// Referenz kennen (die Weiter-Aktionen nach dem Speichern).
  static Future<void> zeigeZuReferenz(BuildContext context, String referenz) {
    final vorgang = getIt<VorgangCubit>().findeZuReferenz(referenz);
    if (vorgang == null) {
      Rueckmeldung.zeigeFehler(
        context,
        'Der Vorgang „$referenz“ ist nicht geladen — die Vollmacht lässt '
        'sich unter „Vorgänge“ drucken.',
      );
      return Future.value();
    }
    return zeige(context, vorgang);
  }

  @override
  Widget build(BuildContext context) {
    return StandNachziehen<VollmachtCubit, VollmachtStand>(
      // Nichts zu füllen: Die Felder lesen den Stand im Aufbau.
      nachziehen: (_, _) {},
      beiUebergang: _melde,
      builder: (context, stand) => AlertDialog(
        title: Row(
          spacing: 8,
          children: [
            const Icon(Icons.draw_outlined),
            Expanded(
              child: Text(
                stand.vorgang == null
                    ? 'Vollmacht'
                    : 'Vollmacht · ${stand.vorgang!.zeichen}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(child: _inhalt(stand)),
        ),
        actions: [VollmachtDialogKnoepfe(stand: stand)],
      ),
    );
  }

  Widget _inhalt(VollmachtStand stand) => switch (stand.phase) {
    VollmachtPhase.laedt => const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: LinearProgressIndicator(),
    ),
    VollmachtPhase.inWordGeoeffnet => VollmachtWordAnsicht(stand: stand),
    // „abgeschlossen" steht nur ein Bild lang, bevor der Dialog schließt —
    // dann bitte als laufender Schritt, nicht als Rückfrage nach dem Vermerk.
    VollmachtPhase.eingabe ||
    VollmachtPhase.arbeitet ||
    VollmachtPhase.abgeschlossen => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VollmachtFormular(stand: stand),
        if (stand.phase != VollmachtPhase.eingabe)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: LinearProgressIndicator(),
          ),
      ],
    ),
  };

  static void _melde(BuildContext context, VollmachtStand stand) {
    final rueckmeldung = Rueckmeldung.von(context);
    final fehler = stand.fehler;
    if (fehler != null) rueckmeldung.fehler(fehler);

    final abschluss = stand.abschluss;
    if (stand.phase == VollmachtPhase.abgeschlossen && abschluss != null) {
      Navigator.of(context).pop();
      stand.abschlussOhneMakel
          ? rueckmeldung.erfolg(abschluss)
          : rueckmeldung.hinweis(abschluss);
    }
  }
}
