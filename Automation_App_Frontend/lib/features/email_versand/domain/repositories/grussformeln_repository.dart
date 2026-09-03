import 'package:automation_app/features/email_versand/domain/entities/grussformel.dart';

/// Der Bestand der persönlichen Grußformeln (§4.7, §7.1). Gepflegt in den
/// Einstellungen, gewählt beim Verfassen.
abstract class GrussformelnRepository {
  /// Alle Grüße in ihrer Reihenfolge — so stehen sie zur Auswahl.
  Future<List<Grussformel>> ladeGrussformeln();

  /// Legt einen Gruß an. Wirft mit einer Meldung im Klartext, wenn es ihn
  /// schon gibt.
  Future<Grussformel> lege(Grussformel grussformel);

  Future<Grussformel> aktualisiere(Grussformel grussformel);

  Future<void> loesche(int id);
}
