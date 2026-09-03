import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_stand.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';

/// Die Nachschlagestellen, aus denen der Mail-Entwurf vorbelegt wird (§4.7):
/// Kanzleidaten, der am Vorgang hinterlegte Mandant, die Sendebereitschaft.
///
/// Eigene Klasse, weil alle drei dieselbe Haltung teilen: **Ein Fehler beim
/// Laden darf den Entwurf nicht verhindern.** Ohne Kanzleidaten fehlt die
/// Unterschrift, ohne Mandant ein Adressvorschlag, ohne Bereitschaft nur die
/// Auskunft, ob gesendet werden kann — alles verschmerzlich. Ein Dialog, der
/// gar nicht erst aufgeht, wäre es nicht.
class EntwurfQuellen {
  final EmailVersandRepository _repository;
  final UseCase<KanzleiSettings, NoParams> _getKanzleiSettings;
  final UseCase<List<Mandant>, NoParams> _getMandanten;

  /// Der **einzige Schreibzugriff** von hier aus: die beim Verfassen gewählte
  /// Anredeart im Register nachtragen (§4.7, ergänzt am 02.09.2026).
  ///
  /// Er steht hier und nicht im Cubit, weil diese Klasse die Stelle ist, die
  /// mit anderen Features spricht — und weil er dieselbe Haltung braucht:
  /// **Misslingt er, bleibt der Entwurf stehen.** Nachgetragen wird nur eine
  /// Lücke, nie eine Korrektur; entschieden wird das am Zustand
  /// (`anredeartNachtragbar`).
  final UseCase<Mandant, Mandant> _updateMandant;

  const EntwurfQuellen(
    this._repository,
    this._getKanzleiSettings,
    this._getMandanten,
    this._updateMandant,
  );

  /// Schreibt [anrede] an [mandant] und gibt den geänderten Mandanten zurück;
  /// null heißt: hat nicht geklappt, und der Aufrufer sagt es dem Anwalt.
  Future<Mandant?> merkeAnredeart(Mandant mandant, Anrede anrede) async {
    final ergebnis = await _updateMandant(mandant.copyWith(anrede: anrede));
    return switch (ergebnis) {
      Right(value: final gemerkt) => gemerkt,
      Left() => null,
    };
  }

  /// Ohne Kanzleidaten fehlt nur die Unterschrift unter dem Entwurf — kein
  /// Grund, den Versand zu verweigern.
  Future<KanzleiSettings> kanzlei() async {
    final ergebnis = await _getKanzleiSettings(const NoParams());
    return switch (ergebnis) {
      Right(value: final settings) => settings,
      Left() => KanzleiSettings.empty,
    };
  }

  /// Der am Vorgang hinterlegte Mandant. Fehlt er oder ist das Register nicht
  /// erreichbar, entfällt nur sein Adressvorschlag — der Entwurf steht
  /// trotzdem.
  Future<Mandant?> mandantZu(Vorgang? vorgang) async {
    final id = vorgang?.mandantId;
    if (id == null) return null;

    final ergebnis = await _getMandanten(const NoParams());
    return switch (ergebnis) {
      Right(value: final mandanten) =>
        mandanten.where((eintrag) => eintrag.id == id).firstOrNull,
      Left() => null,
    };
  }

  /// Kein Zugang, keine Antwort vom Dienst: Der Anwalt soll das sehen, bevor er
  /// tippt — und nicht erst, wenn er auf „Senden" drückt.
  Future<EmailVersandBereitschaft> bereitschaft() async {
    try {
      return await _repository.ladeBereitschaft();
    } catch (e) {
      return EmailVersandBereitschaft(
        bereit: false,
        hinweis: 'Der Postausgang ist nicht erreichbar: ${ausnahmeText(e)}',
      );
    }
  }

  /// Welches Outlook auf diesem Rechner steht. Antwortet der Dienst nicht,
  /// gilt der unbekannte Stand: Dann wird nichts behauptet und nichts
  /// abgeschaltet.
  Future<OutlookStand> outlookStand() async {
    try {
      return await _repository.ladeOutlookStand();
    } catch (_) {
      return OutlookStand.unbekannt;
    }
  }
}
