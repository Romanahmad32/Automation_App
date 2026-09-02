import 'package:automation_app/features/email_versand/domain/entities/anredebaustein.dart';

/// Der Bestand der Anredeanfänge (§4.7, §7.1). Gepflegt in den Einstellungen,
/// gewählt beim Verfassen.
abstract class AnredebausteineRepository {
  /// Alle Anfänge in ihrer Reihenfolge — so stehen sie zur Auswahl.
  Future<List<Anredebaustein>> ladeAnredebausteine();

  /// Legt einen Anfang an. Wirft mit einer Meldung im Klartext, wenn es ihn
  /// schon gibt.
  Future<Anredebaustein> lege(Anredebaustein baustein);

  Future<Anredebaustein> aktualisiere(Anredebaustein baustein);

  Future<void> loesche(int id);
}
