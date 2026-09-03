import 'package:automation_app/features/vorgaenge/domain/entities/referenz_teile.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler.dart';

/// Baut die Meldungen, die der Anwalt bei fehlgeschlagener Persistenz zu sehen
/// bekommt (§7.2: erfasste Daten duerfen nicht stillschweigend verloren
/// gehen).
///
/// Eigene Klasse, damit im [VorgangCubit] die Ablauflogik steht und nicht der
/// Wortlaut: die drei Texte muessen zueinander passen — jeder sagt, was
/// verloren geht, wenn man nichts tut — und das sieht man ihnen nur an, wenn
/// sie beieinander stehen.
abstract final class VorgangPersistenzMeldung {
  static VorgangPersistenzFehler laden() => VorgangPersistenzFehler(
    aktion: VorgangPersistenzAktion.laden,
    meldung:
        'Die gespeicherten Vorgänge konnten nicht geladen werden. '
        'Läuft der Hintergrunddienst?',
  );

  static VorgangPersistenzFehler speichern(Vorgang vorgang) =>
      VorgangPersistenzFehler(
        aktion: VorgangPersistenzAktion.speichern,
        meldung:
            'Der Vorgang „${vorgang.zeichen}" konnte nicht gespeichert '
            'werden. Ohne Speichern geht die Änderung beim Beenden verloren.',
        vorgang: vorgang,
      );

  static VorgangPersistenzFehler loeschen(String referenz) =>
      VorgangPersistenzFehler(
        aktion: VorgangPersistenzAktion.loeschen,
        meldung:
            'Der Vorgang „${ReferenzTeile.zeichenAus(referenz)}" konnte nicht '
            'gelöscht werden und taucht nach einem Neustart wieder auf.',
        referenz: referenz,
      );
}
