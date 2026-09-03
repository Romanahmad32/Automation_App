import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die zwei Wege hinaus (§4.7): **senden** über das Kanzlei-Postfach oder als
/// **Entwurf** ans Mailprogramm übergeben.
///
/// Eigener Baustein neben `OutlookAnhaengeGriff`, weil hier der eine
/// unumkehrbare Schritt des Ablaufs liegt und beide Wege dieselbe Haltung
/// teilen: **Bei einem Fehler ist nichts hinausgegangen, und der Entwurf
/// bleibt vollständig stehen.** Der Anwalt soll nach der Ursache nur noch
/// einmal drücken müssen und nicht neu tippen.
mixin VersandGriff on Cubit<EmailEntwurfState> {
  /// Der Zugang zum Dienst. Der Cubit reicht ihn herein: Ein Mixin in einer
  /// eigenen Datei sieht dessen private Felder nicht.
  EmailVersandRepository get versandRepository;

  /// Der Name der Kanzlei als Absender — kommt aus den Einstellungen, die der
  /// Cubit hält.
  String get absenderName;

  /// Merkt sich den Versuch und meldet, ob die Mail hinaus kann. Ab jetzt
  /// markiert das Formular, was fehlt (§4.7): Der Knopf ist anfassbar, und die
  /// Begründung kommt beim Drücken statt als dauerhafter Kasten über dem
  /// Formular.
  bool istVersandbereit() {
    emit(state.copyWith(versandVersucht: true));
    return state.pruefung.vollstaendig;
  }

  /// Sendet und meldet, ob es geklappt hat. Bei einem Fehler ist nichts
  /// hinausgegangen — der Entwurf bleibt vollständig erhalten, damit der
  /// Anwalt nach der Ursache nur noch einmal auf „Senden" drücken muss.
  Future<bool> senden() async {
    if (!state.kannSenden || !state.pruefung.vollstaendig) return false;
    emit(state.copyWith(phase: EmailVersandPhase.sendet, fehler: () => null));

    try {
      final ergebnis = await versandRepository.sende(
        state.entwurf,
        absenderName: absenderName,
      );
      // Ist der Entwurf inzwischen weg, bleibt die Mail trotzdem versendet —
      // nur zu melden ist es niemandem mehr.
      if (isClosed) return true;
      emit(
        state.copyWith(phase: EmailVersandPhase.gesendet, ergebnis: ergebnis),
      );
      return true;
    } catch (e) {
      if (isClosed) return false;
      emit(
        state.copyWith(
          phase: EmailVersandPhase.verfassen,
          fehler: () => ausnahmeText(e),
        ),
      );
      return false;
    }
  }

  /// Übergibt den Entwurf ans Mailprogramm, statt zu senden (§4.7). Gesendet
  /// wird dort von Hand — deshalb schaltet die Phase **nicht** auf `gesendet`:
  /// Was die App nicht weiß, darf sie im Abschlussdialog nicht behaupten.
  Future<EmailEntwurfErgebnis?> entwurfOeffnen() async {
    if (!state.kannEntwurfOeffnen || !state.pruefung.vollstaendig) return null;
    emit(
      state.copyWith(phase: EmailVersandPhase.uebergibt, fehler: () => null),
    );

    try {
      final ergebnis = await versandRepository.oeffneEntwurf(
        state.entwurf,
        absenderName: absenderName,
      );
      if (isClosed) return ergebnis;
      emit(
        state.copyWith(
          phase: EmailVersandPhase.verfassen,
          entwurfErgebnis: ergebnis,
        ),
      );
      return ergebnis;
    } catch (e) {
      if (isClosed) return null;
      emit(
        state.copyWith(
          phase: EmailVersandPhase.verfassen,
          fehler: () => ausnahmeText(e),
        ),
      );
      return null;
    }
  }
}
