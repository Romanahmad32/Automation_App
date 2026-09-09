import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_aenderung.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/register_historie_zeile.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/historie_herkunft_kasten.dart';
import 'package:automation_app/features/vorgaenge/presentation/widgets/historie_zeile_formular.dart';
import 'package:flutter/material.dart';

/// Was der Anwalt an einer historischen Zeile geändert hat. `null` als Ergebnis
/// des Dialogs heißt „abgebrochen" — ein Ergebnis heißt „so soll die Zeile
/// stehen", und erst danach kommt die Rückfrage.
class HistorieZeileEntscheidung {
  final RegisterHistorieAenderung aenderung;

  const HistorieZeileEntscheidung(this.aenderung);
}

/// Berichtigt eine übernommene Registerzeile (§6.2).
///
/// Der Bestand wird übernommen, wie er ist, und Widersprüche werden als Befund
/// markiert statt still geglättet — die Bereinigung ist Sache des Anwalts, hier
/// und mit Rückfrage. Die Rückfrage stellt **nicht** dieser Dialog: Er liefert
/// nur die Entscheidung zurück, `bestaetigen(...)` steht danach.
///
/// Vorbelegt wird aus dem **Rohstand** der Zeile (`GET
/// /api/RegisterHistorie/{id}`), nicht aus der Anzeigeform der Tabelle. Darüber
/// steht der Herkunftskasten mit der Freitextzelle als Beleg.
class HistorieZeileDialog extends StatefulWidget {
  final RegisterHistorieZeile zeile;

  /// Das Zeichen, unter dem die Zeile in der Tabelle steht („10/19-I C02").
  /// Es kommt von dort und wird hier nicht ein zweites Mal gebaut — sonst
  /// stünde im Dialogtitel ein anderes Zeichen als in der Zeile darunter.
  final String zeichen;

  const HistorieZeileDialog({
    super.key,
    required this.zeile,
    required this.zeichen,
  });

  @override
  State<HistorieZeileDialog> createState() => HistorieZeileDialogState();
}

class HistorieZeileDialogState extends State<HistorieZeileDialog> {
  late final HistorieZeileFelder _felder = HistorieZeileFelder.ausAenderung(
    RegisterHistorieAenderung.aus(widget.zeile),
  );

  @override
  void dispose() {
    _felder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Registereintrag ${widget.zeichen} bearbeiten'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              HistorieHerkunftKasten(zeile: widget.zeile),
              HistorieZeileFormular(felder: _felder),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(HistorieZeileEntscheidung(_felder.alsAenderung())),
          child: const Text('Änderung übernehmen'),
        ),
      ],
    );
  }
}
