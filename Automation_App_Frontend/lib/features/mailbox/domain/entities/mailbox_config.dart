import 'package:equatable/equatable.dart';

/// Der in den Einstellungen hinterlegte Postfach-Zugang für die automatische
/// Überwachung der Zentralruf-Antworten (REQUIREMENTS.md §4.3/§7.1). Spiegelt das
/// Backend-DTO `MailboxConfigDto`: Das App-Passwort selbst wird nie ausgeliefert,
/// nur ob bereits eines gesetzt ist ([appPasswordSet]).
/// Anmeldeverfahren des Postfach-Zugangs (spiegelt das Backend-Enum
/// `MailboxAuthMethod`): App-Passwort (Gmail) oder Microsoft-Anmeldung
/// (Outlook — dort ist OAuth seit September 2024 der einzige Weg).
enum MailboxAuthMethod {
  appPassword('AppPassword'),
  microsoftOAuth('MicrosoftOAuth');

  /// Der Wert, wie ihn die Backend-API sendet/erwartet.
  final String apiValue;

  const MailboxAuthMethod(this.apiValue);

  static MailboxAuthMethod fromApi(String? value) =>
      value?.toLowerCase() == 'microsoftoauth'
      ? MailboxAuthMethod.microsoftOAuth
      : MailboxAuthMethod.appPassword;
}

class MailboxConfig extends Equatable {
  /// Schaltet die Überwachung an. Ohne Zugang bleibt sie inaktiv.
  final bool enabled;

  /// Wie sich der Monitor anmeldet: App-Passwort (Gmail) oder Microsoft-OAuth.
  final MailboxAuthMethod authMethod;

  /// True, wenn im Backend eine Azure-Client-ID hinterlegt ist und die
  /// Microsoft-Anmeldung damit möglich ist.
  final bool microsoftAuthAvailable;

  /// E-Mail-Adresse des angemeldeten Microsoft-Kontos, sonst null.
  final String? microsoftAccount;

  final String host;
  final int port;

  /// SSL/TLS direkt beim Verbindungsaufbau (Port 993). Für STARTTLS false.
  final bool useSsl;

  /// Vollständige E-Mail-Adresse des Postfachs (für Gmail die Gmail-Adresse).
  final String username;

  /// True, wenn bereits ein App-Passwort gespeichert ist (das Passwort selbst
  /// liefert das Backend aus Sicherheitsgründen nicht zurück).
  final bool appPasswordSet;

  final String folder;

  /// Nur Mails mit dieser Zeichenkette im Betreff auswerten (leer = alle).
  final String subjectFilter;

  const MailboxConfig({
    this.enabled = false,
    this.authMethod = MailboxAuthMethod.appPassword,
    this.microsoftAuthAvailable = false,
    this.microsoftAccount,
    this.host = 'imap.gmail.com',
    this.port = 993,
    this.useSsl = true,
    this.username = '',
    this.appPasswordSet = false,
    this.folder = 'INBOX',
    this.subjectFilter = 'Zentralruf',
  });

  static const MailboxConfig empty = MailboxConfig();

  factory MailboxConfig.fromJson(Map<String, dynamic> json) {
    return MailboxConfig(
      enabled: json['enabled'] as bool? ?? false,
      authMethod: MailboxAuthMethod.fromApi(json['authMethod'] as String?),
      microsoftAuthAvailable: json['microsoftAuthAvailable'] as bool? ?? false,
      microsoftAccount: json['microsoftAccount'] as String?,
      host: json['host'] as String? ?? 'imap.gmail.com',
      port: (json['port'] as num?)?.toInt() ?? 993,
      useSsl: json['useSsl'] as bool? ?? true,
      username: json['username'] as String? ?? '',
      appPasswordSet: json['appPasswordSet'] as bool? ?? false,
      folder: json['folder'] as String? ?? 'INBOX',
      subjectFilter: json['subjectFilter'] as String? ?? 'Zentralruf',
    );
  }

  @override
  List<Object?> get props => [
    enabled,
    authMethod,
    microsoftAuthAvailable,
    microsoftAccount,
    host,
    port,
    useSsl,
    username,
    appPasswordSet,
    folder,
    subjectFilter,
  ];
}

/// Eine Änderung des Postfach-Zugangs, wie sie an das Backend geschickt wird.
/// [appPassword] null = unverändert lassen; ein Wert setzt es neu.
class MailboxConfigUpdate extends Equatable {
  final bool enabled;
  final MailboxAuthMethod authMethod;
  final String host;
  final int port;
  final bool useSsl;
  final String username;
  final String? appPassword;
  final String folder;
  final String subjectFilter;

  const MailboxConfigUpdate({
    required this.enabled,
    required this.authMethod,
    required this.host,
    required this.port,
    required this.useSsl,
    required this.username,
    required this.appPassword,
    required this.folder,
    required this.subjectFilter,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'authMethod': authMethod.apiValue,
    'host': host,
    'port': port,
    'useSsl': useSsl,
    'username': username,
    'appPassword': appPassword,
    'folder': folder,
    'subjectFilter': subjectFilter,
  };

  @override
  List<Object?> get props => [
    enabled,
    authMethod,
    host,
    port,
    useSsl,
    username,
    appPassword,
    folder,
    subjectFilter,
  ];
}
