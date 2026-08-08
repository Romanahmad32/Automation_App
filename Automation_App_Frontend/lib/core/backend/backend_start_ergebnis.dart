import 'package:automation_app/core/backend/app_version.dart';

/// Wie der lokale Dienst zur Verfügung steht.
enum BackendStartStatus {
  /// Der Dienst lief bereits — beim Entwickeln der Normalfall (`dotnet run`).
  bereitsGestartet,

  /// Die Anwendung hat ihn selbst als Kindprozess gestartet.
  selbstGestartet,

  /// Er steht nicht zur Verfügung; die Anwendung ist ohne ihn nicht arbeitsfähig.
  fehlgeschlagen,
}

/// Ergebnis des Startversuchs samt Meldung für den Anwender.
class BackendStartErgebnis {
  const BackendStartErgebnis.bereitsGestartet(this.version)
    : status = BackendStartStatus.bereitsGestartet,
      meldung = null;

  const BackendStartErgebnis.selbstGestartet(this.version)
    : status = BackendStartStatus.selbstGestartet,
      meldung = null;

  const BackendStartErgebnis.fehlgeschlagen(this.meldung)
    : status = BackendStartStatus.fehlgeschlagen,
      version = null;

  final BackendStartStatus status;

  /// Nur im Fehlerfall gesetzt: Klartext, der dem Anwender angezeigt wird.
  final String? meldung;

  /// Nur im Erfolgsfall gesetzt: die Version, die der Dienst über `/health`
  /// gemeldet hat. Die Anwendung zeigt sie in der Seitenleiste.
  final AppVersion? version;

  bool get erfolgreich => status != BackendStartStatus.fehlgeschlagen;
}
