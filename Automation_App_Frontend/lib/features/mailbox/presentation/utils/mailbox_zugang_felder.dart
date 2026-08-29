import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Übersetzt zwischen dem Formular des Postfach-Zugangs und der
/// Konfiguration (§4.3/§7.1) — in beide Richtungen.
///
/// Eigener Baustein, weil die Maske daneben inzwischen mehr ist als dieses
/// eine Formular: Sie trägt den Zugang, die Signatur und den einen
/// Speichern-Knopf für beides. Was rein Feldnamen-Arbeit ist, gehört nicht in
/// dieselbe Datei wie der Aufbau der Seite.
abstract final class MailboxZugangFelder {
  /// Setzt die Felder auf den geladenen Stand.
  static void fuelle(FormGroup form, MailboxConfig config) {
    form.patchValue({
      'enabled': config.enabled,
      'authMethod': config.authMethod,
      'host': config.host,
      'port': config.port.toString(),
      'useSsl': config.useSsl,
      'username': config.username,
      // Das gespeicherte Passwort liefert das Backend nie aus; Feld bleibt leer.
      'appPassword': '',
      'folder': config.folder,
      'subjectFilter': config.subjectFilter,
    });
  }

  /// Die Änderung, wie sie ans Backend geht.
  ///
  /// [stand] ist die zuletzt geladene Konfiguration — aus ihr kommt beim
  /// Outlook-Weg das angemeldete Konto. [appPasswortGesetzt] sagt, ob schon
  /// eines hinterlegt ist: Dann heißt ein leeres Feld „unverändert" und nicht
  /// „löschen".
  static MailboxConfigUpdate alsAenderung(
    FormGroup form, {
    required MailboxConfig stand,
    required bool appPasswortGesetzt,
  }) {
    final value = form.value;
    String read(String key) => (value[key] as String?)?.trim() ?? '';

    final authMethod =
        (value['authMethod'] as MailboxAuthMethod?) ??
        MailboxAuthMethod.appPassword;
    final microsoft = authMethod == MailboxAuthMethod.microsoftOAuth;

    final passwordInput = read('appPassword');
    final String? appPassword = passwordInput.isEmpty
        ? (appPasswortGesetzt ? null : '')
        : passwordInput;

    return MailboxConfigUpdate(
      enabled: (value['enabled'] as bool?) ?? false,
      authMethod: authMethod,
      // Beim Outlook-Weg sind Server und Konto durch die Anmeldung
      // festgelegt — der Nutzer soll nichts davon pflegen müssen.
      host: microsoft ? 'outlook.office365.com' : read('host'),
      port: microsoft ? 993 : int.tryParse(read('port')) ?? 993,
      useSsl: microsoft ? true : (value['useSsl'] as bool?) ?? true,
      username: microsoft
          ? (stand.microsoftAccount ?? read('username'))
          : read('username'),
      appPassword: microsoft ? null : appPassword,
      folder: read('folder'),
      subjectFilter: read('subjectFilter'),
    );
  }
}
