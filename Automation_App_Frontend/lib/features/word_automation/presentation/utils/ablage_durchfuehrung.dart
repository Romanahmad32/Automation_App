import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/ablage_strategie.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/ablage_cubit/ablage_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/ablage_format.dart';
import 'package:automation_app/features/word_automation/domain/usecases/erzeuge_pdf_fassung.dart';
import 'package:automation_app/features/word_automation/presentation/widgets/ablage_konflikt_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Stößt die Ablage in der Akte an (§6.1): stellt zum gewählten [format] die
/// Quelldateien zusammen und übergibt sie dem [AblageCubit]. Die Word-Fassung
/// steht bewusst vorn — bei einer Rückfrage entscheidet der Anwalt zuerst über
/// die bearbeitbare Datei.
///
/// Das PDF entsteht erst hier, neben der Word-Datei: im Arbeitsordner des
/// Vorgangs, den die Aufräumung nach der Ablage mitnimmt (§4.6). Es dauert
/// (Word konvertiert) und kann fehlschlagen (Word nicht installiert, Dokument
/// noch offen) — dann wird **nichts** abgelegt. Eine halbe Ablage ist schwerer
/// zu durchschauen als eine, die gar nicht stattgefunden hat.
Future<void> starteAblage(
  BuildContext context, {
  required int mandantId,
  required String aktenOrdnername,
  required String unterordnerName,
  required String wordPfad,
  required AblageFormat format,
}) async {
  final cubit = context.read<AblageCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final quellen = <String>[if (format.mitWord) wordPfad];

  if (format.mitPdf) {
    final ergebnis = await getIt<UseCase<String, ErzeugePdfFassungParams>>()(
      ErzeugePdfFassungParams(wordPfad),
    );
    switch (ergebnis) {
      case Right(value: final pdfPfad):
        quellen.add(pdfPfad);
      case Left(value: final failure):
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Die PDF-Fassung konnte nicht erstellt werden: '
              '${failure.message}',
            ),
            duration: const Duration(seconds: 10),
            showCloseIcon: true,
          ),
        );
        return;
    }
  }

  await cubit.ablegenFuerMandant(
    mandantId: mandantId,
    aktenOrdnername: aktenOrdnername,
    unterordnerName: unterordnerName,
    quelldateiPfade: quellen,
  );
}

/// Im Fall-Ordner liegen schon gleichnamige Dateien: entscheiden lassen und
/// die Antwort an den [AblageCubit] zurückgeben. Ein Abbruch lässt die Akte
/// unverändert — geschrieben wurde zu diesem Zeitpunkt noch nichts.
Future<void> klaereAblageKonflikt(
  BuildContext context,
  List<String> vorhandenePfade,
) async {
  final cubit = context.read<AblageCubit>();
  final strategie = await frageAblageKonflikt(context, vorhandenePfade);
  if (strategie == null) {
    cubit.konfliktAbbrechen();
    return;
  }
  await cubit.konfliktLoesen(strategie);
}

/// Rückfrage, wenn im Fall-Ordner bereits gleichnamige Dateien liegen (§6.1).
/// Null = abgebrochen; dann bleibt die Akte unverändert.
Future<AblageStrategie?> frageAblageKonflikt(
  BuildContext context,
  List<String> vorhandenePfade,
) => showDialog<AblageStrategie>(
  context: context,
  builder: (_) => AblageKonfliktDialog(vorhandenePfade: vorhandenePfade),
);
