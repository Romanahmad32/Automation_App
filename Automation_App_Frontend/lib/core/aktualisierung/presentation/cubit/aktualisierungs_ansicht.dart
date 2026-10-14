import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_stand.dart';
import 'package:automation_app/core/aktualisierung/domain/entities/aktualisierungs_zustand.dart';
import 'package:automation_app/core/aktualisierung/presentation/cubit/aktualisierungs_dialog_phase.dart';
import 'package:equatable/equatable.dart';

/// Was die Oberfläche über die Aktualisierung weiß (#196) — der Zustand des
/// `AktualisierungCubit`, gelesen von Seitenleiste, Dialog und „Über“.
///
/// [ablehnung] und [testmodusNeustart] sind **einmalig**: [mit] setzt sie
/// zurück, wenn sie nicht ausdrücklich mitgegeben werden. Ein Listener sieht
/// sie also genau einmal, beim Übergang.
class AktualisierungsAnsicht extends Equatable {
  const AktualisierungsAnsicht({
    this.stand,
    this.dienstStumm = false,
    this.arbeitet = false,
    this.schliesstGerade = false,
    this.ablehnung,
    this.testmodusNeustart = false,
  });

  /// Vor der ersten Antwort des Dienstes.
  static const AktualisierungsAnsicht anfang = AktualisierungsAnsicht();

  /// Der letzte bekannte Stand des Dienstes; `null` vor der ersten Antwort.
  final AktualisierungsStand? stand;

  /// Der Dienst hat auf die Frage nach dem Stand nicht geantwortet — dann
  /// heißt es „konnte nicht nachsehen“, nicht „wird nachgesehen“.
  final bool dienstStumm;

  /// Ein Schritt ist unterwegs; die Knöpfe sind so lange gesperrt.
  final bool arbeitet;

  /// Der Installer läuft, die App wird gleich geschlossen (2e).
  final bool schliesstGerade;

  /// Satz für eine Fehler-Rückmeldung — der Dienst hat abgelehnt (409) oder
  /// nicht geantwortet. Einmalig.
  final String? ablehnung;

  /// Im E2E-Testmodus wurde der Installer „gestartet“ (nur protokolliert);
  /// die App bleibt offen, der Dialog geht zu. Einmalig.
  final bool testmodusNeustart;

  AktualisierungsZustand? get zustand => stand?.zustand;

  /// Ob es etwas zu aktualisieren gibt — Hinweis und Knopf hängen daran.
  bool get updateInSicht => stand?.updateInSicht ?? false;

  AktualisierungsDialogPhase get dialogPhase {
    if (schliesstGerade) return AktualisierungsDialogPhase.schliesst;
    if (!updateInSicht) return AktualisierungsDialogPhase.ohneUpdate;
    return switch (zustand) {
      AktualisierungsZustand.laedt => AktualisierungsDialogPhase.laedt,
      AktualisierungsZustand.bereit => AktualisierungsDialogPhase.bereit,
      AktualisierungsZustand.fehler => AktualisierungsDialogPhase.fehler,
      _ => AktualisierungsDialogPhase.verfuegbar,
    };
  }

  AktualisierungsAnsicht mit({
    AktualisierungsStand? stand,
    bool? dienstStumm,
    bool? arbeitet,
    bool? schliesstGerade,
    String? ablehnung,
    bool testmodusNeustart = false,
  }) => AktualisierungsAnsicht(
    stand: stand ?? this.stand,
    dienstStumm: dienstStumm ?? this.dienstStumm,
    arbeitet: arbeitet ?? this.arbeitet,
    schliesstGerade: schliesstGerade ?? this.schliesstGerade,
    ablehnung: ablehnung,
    testmodusNeustart: testmodusNeustart,
  );

  @override
  List<Object?> get props => [
    stand,
    dienstStumm,
    arbeitet,
    schliesstGerade,
    ablehnung,
    testmodusNeustart,
  ];
}
