import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_config_bloc/mailbox_config_bloc.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_auth_method_selector.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_enabled_switch.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_filter_section.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_imap_credentials_section.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_imap_server_section.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_microsoft_signin_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Einstellungsmaske für den Postfach-Zugang (REQUIREMENTS.md §4.3/§7.1). Mit
/// diesen Angaben überwacht das Backend das Postfach ereignisbasiert und erfasst
/// eingehende Zentralruf-Antworten selbsttätig. Zwei Wege, und es entscheidet
/// allein, wo das Postfach liegt: IMAP mit Passwort (1&1/IONOS, Gmail) oder
/// Outlook/Microsoft per Browser-Anmeldung (OAuth — Microsoft erlaubt für IMAP
/// kein Passwort mehr). Über denselben Zugang wird auch versendet (§4.7).
class MailboxAccessView extends StatefulWidget {
  const MailboxAccessView({super.key});

  @override
  State<MailboxAccessView> createState() => _MailboxAccessViewState();
}

class _MailboxAccessViewState extends State<MailboxAccessView>
    with AutomaticKeepAliveClientMixin {
  bool _initialized = false;

  // Liegt im selben TabBarView wie die Kanzleidaten. KeepAlive verhindert, dass
  // die TabBarView den State beim Tab-Wechsel verwirft und das Formular leer
  // neu aufbaut (der Listener würde sonst nicht erneut befüllen).
  @override
  bool get wantKeepAlive => true;

  /// Ob bereits ein App-Passwort gespeichert ist — dann darf das Feld leer
  /// bleiben (unverändert), und wir schicken kein null-überschreibendes Passwort.
  bool _appPasswordSet = false;

  /// Zuletzt geladene Konfiguration (für die Microsoft-Konto-Anzeige).
  MailboxConfig _config = MailboxConfig.empty;

  final ScrollController _scrollController = ScrollController();

  final FormGroup _form = FormGroup({
    'enabled': FormControl<bool>(value: false),
    'authMethod': FormControl<MailboxAuthMethod>(
      value: MailboxAuthMethod.appPassword,
    ),
    'host': FormControl<String>(
      value: 'imap.ionos.de',
      validators: [Validators.required],
    ),
    'port': FormControl<String>(
      value: '993',
      validators: [Validators.required, Validators.number()],
    ),
    'useSsl': FormControl<bool>(value: true),
    'username': FormControl<String>(validators: [Validators.email]),
    'appPassword': FormControl<String>(),
    'folder': FormControl<String>(
      value: 'INBOX',
      validators: [Validators.required],
    ),
    'subjectFilter': FormControl<String>(value: 'Zentralruf'),
  });

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _patch(MailboxConfig config) {
    _config = config;
    _appPasswordSet = config.appPasswordSet;
    _form.patchValue({
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

  void _save() {
    final value = _form.value;
    String read(String key) => (value[key] as String?)?.trim() ?? '';

    final authMethod =
        (value['authMethod'] as MailboxAuthMethod?) ??
        MailboxAuthMethod.appPassword;
    final microsoft = authMethod == MailboxAuthMethod.microsoftOAuth;

    final passwordInput = read('appPassword');
    // Leer + bereits gesetzt = unverändert lassen (null). Sonst neuer Wert.
    final String? appPassword = passwordInput.isEmpty
        ? (_appPasswordSet ? null : '')
        : passwordInput;

    context.read<MailboxConfigBloc>().add(
      SaveMailboxConfigEvent(
        MailboxConfigUpdate(
          enabled: (value['enabled'] as bool?) ?? false,
          authMethod: authMethod,
          // Beim Outlook-Weg sind Server und Konto durch die Anmeldung
          // festgelegt — der Nutzer soll nichts davon pflegen müssen.
          host: microsoft ? 'outlook.office365.com' : read('host'),
          port: microsoft ? 993 : int.tryParse(read('port')) ?? 993,
          useSsl: microsoft ? true : (value['useSsl'] as bool?) ?? true,
          username: microsoft
              ? (_config.microsoftAccount ?? read('username'))
              : read('username'),
          appPassword: microsoft ? null : appPassword,
          folder: read('folder'),
          subjectFilter: read('subjectFilter'),
        ),
      ),
    );
  }

  void _onLoaded(BuildContext context, MailboxConfigLoaded state) {
    if (!_initialized || state.justSignedIn) {
      // Nach der Microsoft-Anmeldung hat das Backend Konto und Server
      // übernommen — die Maske muss die neuen Werte zeigen.
      _patch(state.config);
      setState(() => _initialized = true);
    } else {
      _config = state.config;
      _appPasswordSet = state.config.appPasswordSet;
    }

    final message = state.justSignedIn
        ? 'Microsoft-Anmeldung erfolgreich — das Postfach '
              '${state.config.microsoftAccount ?? ''} wird verwendet.'
        : state.justSaved
        ? 'Postfach-Zugang gespeichert. Die Überwachung verbindet sich '
              'mit den neuen Werten neu.'
        : null;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return BlocConsumer<MailboxConfigBloc, MailboxConfigState>(
      listener: (context, state) {
        if (state is MailboxConfigLoaded) {
          _onLoaded(context, state);
        } else if (state is MailboxConfigError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        if (!_initialized && state is MailboxConfigLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final isSaving = state is MailboxConfigLoading;
        final signInPending = state is MailboxMicrosoftSignInPending;

        return Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ReactiveForm(
                    formGroup: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        const FormSection(
                          icon: Icons.mark_email_unread,
                          title: 'Postfach-Überwachung',
                          subtitle:
                              'Ist ein Zugang hinterlegt und die Überwachung '
                              'eingeschaltet, erfasst die App eingehende '
                              'Zentralruf-Antworten automatisch (erkannt über den '
                              'Betreff). Ohne Zugang bleibt sie inaktiv.',
                          children: [
                            MailboxEnabledSwitch(),
                            MailboxAuthMethodSelector(),
                          ],
                        ),
                        ReactiveValueListenableBuilder<MailboxAuthMethod>(
                          formControlName: 'authMethod',
                          builder: (context, control, _) {
                            final microsoft =
                                control.value ==
                                MailboxAuthMethod.microsoftOAuth;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 16,
                              children: microsoft
                                  ? [
                                      MailboxMicrosoftSignInSection(
                                        config: _config,
                                        signInPending: signInPending,
                                      ),
                                    ]
                                  : [
                                      MailboxImapCredentialsSection(
                                        appPasswordSet: _appPasswordSet,
                                      ),
                                      const MailboxImapServerSection(),
                                    ],
                            );
                          },
                        ),
                        const MailboxFilterSection(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ReactiveFormConsumer(
                            builder: (context, form, child) {
                              return FilledButton.icon(
                                icon: isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save),
                                label: const Text('Speichern'),
                                onPressed:
                                    (form.valid && !isSaving && !signInPending)
                                    ? _save
                                    : null,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
