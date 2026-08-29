import 'dart:async';

import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_anhaenge.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Der Griff nach den Anhängen der Nachricht, die in Outlook gerade offen oder
/// markiert ist (§4.7).
///
/// Eigener Baustein, weil er als einziger Teil des Entwurfs nach draußen
/// greift: Was er zu fassen bekommt, bestimmt nicht die App, sondern was der
/// Anwalt in Outlook vor sich hat. Alles daran — die Vorschläge, die Herkunft,
/// das Verwerfen — gehört zusammen und nirgendwo sonst hin.
mixin OutlookAnhaengeGriff on Cubit<EmailEntwurfState> {
  /// Der Zugang zum Dienst. Der Cubit reicht ihn herein: Ein Mixin in einer
  /// eigenen Datei sieht dessen private Felder nicht.
  EmailVersandRepository get versandRepository;

  /// Holt die Anhänge aus der Nachricht, die in Outlook gerade offen ist, und
  /// **bietet** sie an. Angehängt werden sie erst auf Klick — wie die Dateien
  /// aus dem Fall-Ordner.
  ///
  /// Meldet beides: was der Griff gefasst hat (samt Betreff der Nachricht) und
  /// wie viel davon neu ist. Wer zweimal drückt, soll „liegt schon da" zu sehen
  /// bekommen und nicht ein Fenster, in dem sich nichts rührt. Null heißt:
  /// gescheitert, der Grund steht im Zustand.
  Future<({OutlookAnhaenge griff, int neu})?> anhaengeAusOutlook() async {
    if (state.holtAusOutlook) return null;
    emit(state.copyWith(holtAusOutlook: true, fehler: () => null));

    try {
      final geholt = await versandRepository.ladeOutlookAnhaenge();

      // Was schon angehängt oder schon angeboten ist, nicht doppelt zeigen.
      // Der Dienst legt je Nachricht denselben Pfad an, deshalb trägt der
      // Vergleich auch beim zweiten Griff nach derselben Mail.
      final bekannt = {...state.ausOutlook, ...state.entwurf.anhangPfade};
      final neu = geholt.pfade
          .where((pfad) => !bekannt.contains(pfad))
          .toList();
      if (isClosed) return (griff: geholt, neu: neu.length);

      emit(
        state.copyWith(
          holtAusOutlook: false,
          ausOutlook: [...state.ausOutlook, ...neu],
          outlookQuelle: geholt,
        ),
      );
      return (griff: geholt, neu: neu.length);
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(holtAusOutlook: false, fehler: () => ausnahmeText(e)),
      );
      return null;
    }
  }

  /// Nimmt einen aus Outlook geholten Vorschlag aus der Reihe **und** loescht
  /// die zwischengelagerte Datei: Was der Anwalt verwirft, soll nicht in der
  /// Ablage liegen bleiben. Der Rueckweg bleibt das erneute Holen — die
  /// Nachricht liegt ja weiter im Postfach.
  void outlookAnhangVerwerfen(String pfad) {
    emit(
      state.copyWith(
        ausOutlook: state.ausOutlook
            .where((vorhanden) => vorhanden != pfad)
            .toList(),
      ),
    );
    unawaited(versandRepository.verwirfAnhang(pfad));
  }
}
