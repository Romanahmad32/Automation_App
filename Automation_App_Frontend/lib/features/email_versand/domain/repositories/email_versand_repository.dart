import 'package:automation_app/features/email_versand/domain/entities/email_entwurf.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_entwurf_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_bereitschaft.dart';
import 'package:automation_app/features/email_versand/domain/entities/email_versand_ergebnis.dart';
import 'package:automation_app/features/email_versand/domain/entities/outlook_signatur.dart';

/// Zugang zum Postausgang der Kanzlei (§4.7).
abstract class EmailVersandRepository {
  /// Kann überhaupt gesendet werden, und von welcher Adresse aus?
  Future<EmailVersandBereitschaft> ladeBereitschaft();

  /// Sendet den Entwurf. Wirft mit einer Meldung im Klartext, wenn nichts
  /// hinausgegangen ist — einen Teilerfolg gibt es nicht.
  Future<EmailVersandErgebnis> sende(
    EmailEntwurf entwurf, {
    required String absenderName,
  });

  /// Öffnet den Entwurf im Mailprogramm, statt zu senden. Dort stehen Signatur
  /// und Vorlage der Kanzlei bereits, und dorthin zieht der Anwalt an, was die
  /// App nicht kennt.
  Future<EmailEntwurfErgebnis> oeffneEntwurf(
    EmailEntwurf entwurf, {
    required String absenderName,
  });

  /// Stösst den Start von Outlook an, damit der erste Entwurf den Kaltstart
  /// nicht bezahlt. Ohne Rückmeldung und ohne Folgen, wenn es misslingt.
  Future<void> waermeEntwurfVor();

  /// Die Anhänge der Nachricht, die in Outlook gerade offen oder ausgewählt
  /// ist — abgelegt und mit vollem Pfad. Leer, wenn nichts ausgewählt ist.
  Future<List<String>> ladeOutlookAnhaenge();

  /// Die im Mailprogramm dieses Rechners eingerichteten Signaturen, zum
  /// einmaligen Übernehmen in die Einstellungen (§4.7). Leere Liste heißt: hier
  /// ist keine eingerichtet — kein Fehler.
  Future<List<OutlookSignatur>> ladeOutlookSignaturen();
}
