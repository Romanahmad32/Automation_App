import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang_status.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/word_automation/domain/entities/arbeitsordner_aufraeumung.dart';
import 'package:automation_app/features/word_automation/domain/usecases/arbeitsordner_aufraeumen.dart';
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Was nach der geglückten Ablage in der Akte zu tun ist (§4.6):
///
/// 1. Der Vorgang steht auf „abgelegt" und zeigt auf die abgelegte Datei
///    (nur vorwärts — ein bereits versendeter Vorgang fällt nicht zurück).
/// 2. Der Wizard arbeitet ab hier mit der Datei **in der Akte** weiter.
/// 3. Der Arbeitsordner des Vorgangs verschwindet. Ab jetzt ist die Kopie in
///    der Akte die gültige Fassung; die Zwischenstände der Korrekturschleife
///    haben ausgedient — genau darum darf Schritt 2 nicht fehlen.
Future<void> schliesseAblageAb(
  BuildContext context, {
  required Vorgang? vorgang,
  required String? zielpfad,
  required String aktenOrdner,
}) async {
  if (vorgang != null && vorgang.status.index < VorgangStatus.abgelegt.index) {
    getIt<VorgangCubit>().aktualisiere(
      vorgang.copyWith(
        status: VorgangStatus.abgelegt,
        dokumentPfad: zielpfad,
        aktenOrdner: aktenOrdner,
      ),
    );
  }

  if (zielpfad != null) {
    context.read<EditedDocumentBloc>().add(DokumentAbgelegtEvent(zielpfad));
  }

  // Vor dem await greifen: danach kann der BuildContext weg sein.
  final messenger = ScaffoldMessenger.of(context);
  final ergebnis =
      await getIt<
        UseCase<ArbeitsordnerAufraeumung, ArbeitsordnerAufraeumenParams>
      >()(ArbeitsordnerAufraeumenParams(vorgang?.referenz ?? ''));

  switch (ergebnis) {
    case Right(value: final aufraeumung):
      final meldung = aufraeumung.meldung;
      // Nur melden, wenn wirklich etwas liegen blieb. Das abgelegte Dokument
      // ist davon nicht betroffen — kein Grund, den Erfolg zu verdecken.
      if (!aufraeumung.erfolg && meldung != null) {
        messenger.showSnackBar(SnackBar(content: Text(meldung)));
      }
    case Left():
      // Der Dienst ist nicht erreichbar. Das Dokument liegt in der Akte; die
      // Arbeitskopie räumt spätestens die Startaufräumung des Dienstes weg.
      break;
  }
}
