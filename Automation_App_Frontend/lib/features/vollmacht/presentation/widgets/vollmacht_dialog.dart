import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/core/general_widgets/stand_nachziehen.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_cubit.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_katalog_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_cubit.dart';
import 'package:automation_app/features/vollmacht/presentation/blocs/vollmacht_stand.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_arbeitsflaeche.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_dialog_knoepfe.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_ergebnis_ansicht.dart';
import 'package:automation_app/features/vollmacht/presentation/widgets/vollmacht_word_ansicht.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der eine Dialog für die Vollmacht zum Vorgang (§4.11) — erreichbar aus
/// „Vorgang starten" nach dem Speichern und aus jeder Kachel in „Vorgänge".
///
/// Er zeigt die vorbelegten Kopfdaten zur Korrektur samt Seitenvorschau und
/// Drucker, druckt, fällt bei einem gescheiterten Druck auf Word zurück und
/// vermerkt den Druck am Vorgang. Danach bleibt er mit dem Ergebnis stehen,
/// bis der Anwalt „Fertig" drückt (#164) — die App weiß nicht, ob wirklich
/// ein Blatt herauskam. Den Ablauf trägt der [VollmachtCubit]; dieser
/// Baustein zeigt nur, wo der gerade steht.
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
      // Die Felder lesen den Stand im Aufbau. Nachzuziehen ist nur die erste
      // Seitenvorschau, sobald sie fällig ist — nach dem Bild, denn beim
      // Aufgehen läuft dieser Rückruf mitten im Aufbau.
      nachziehen: (context, stand) {
        if (!stand.vorschauFaellig) return;
        final cubit = context.read<VollmachtCubit>();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => cubit.erstelleVorschau(),
        );
      },
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
        content: _inhalt(context, stand),
        actions: [VollmachtDialogKnoepfe(stand: stand)],
      ),
    );
  }

  /// Vor dem Druck mit Vorschau so breit, wie das Fenster es hergibt; danach
  /// — in Word oder im Ergebnis — reicht die schmale Fassung.
  Widget _inhalt(BuildContext context, VollmachtStand stand) {
    Widget schmal(Widget kind) => SizedBox(
      width: VollmachtArbeitsflaeche.breiteUntereinander,
      child: SingleChildScrollView(child: kind),
    );

    return switch (stand.phase) {
      VollmachtPhase.laedt => schmal(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: LinearProgressIndicator(),
        ),
      ),
      VollmachtPhase.inWordGeoeffnet => schmal(
        VollmachtWordAnsicht(stand: stand),
      ),
      VollmachtPhase.abgeschlossen => schmal(
        VollmachtErgebnisAnsicht(stand: stand),
      ),
      VollmachtPhase.eingabe || VollmachtPhase.arbeitet => SizedBox(
        width: VollmachtArbeitsflaeche.nebeneinander(context)
            ? VollmachtArbeitsflaeche.breiteNebeneinander
            : VollmachtArbeitsflaeche.breiteUntereinander,
        child: VollmachtArbeitsflaeche(stand: stand),
      ),
    };
  }

  static void _melde(BuildContext context, VollmachtStand stand) {
    final rueckmeldung = Rueckmeldung.von(context);
    final fehler = stand.fehler;
    if (fehler != null) rueckmeldung.fehler(fehler);
    final hinweis = stand.hinweis;
    if (hinweis != null) rueckmeldung.hinweis(hinweis);
  }
}
