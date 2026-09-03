import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';

/// Der Bestand der Mail-Textvorlagen (§4.7, §5.3). Gepflegt in den
/// Einstellungen, gelesen beim Verfassen.
abstract class MailVorlagenRepository {
  /// Alle Vorlagen, nach Namen sortiert — so stehen sie zur Auswahl.
  Future<List<MailVorlage>> ladeVorlagen();

  /// Legt eine Vorlage an und liefert sie mit ihrer vergebenen Nummer zurück.
  /// Wirft mit einer Meldung im Klartext, wenn der Name schon vergeben ist.
  Future<MailVorlage> lege(MailVorlage vorlage);

  /// Schreibt eine vorhandene Vorlage. Wirft wie [lege] bei doppeltem Namen.
  Future<MailVorlage> aktualisiere(MailVorlage vorlage);

  Future<void> loesche(int id);
}
